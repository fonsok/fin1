import Foundation

extension InvestmentService {
    // MARK: - Investment Creation

    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        poolSelection: InvestmentSelectionStrategy
    ) async throws {
        let existingIds = await MainActor.run { Set(repository.investments.map(\.id)) }

        let deferCashDeductions = investmentAPIService != nil
        let (batch, investments, createdPoolIds) = try await creationService.createInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            poolSelection: poolSelection,
            repository: repository,
            deferCashDeductions: deferCashDeductions
        )

        let newIds = await MainActor.run {
            repository.investments.map(\.id).filter { !existingIds.contains($0) }
        }
        for id in newIds {
            markForSync(id)
        }

        if !newIds.isEmpty, investmentAPIService != nil {
            do {
                try await syncPendingInvestmentsToBackend(propagateFirstFailure: true)
            } catch let error as NetworkError {
                await rollbackLocalInvestmentDraft(
                    newInvestmentIds: newIds,
                    batchId: batch.id,
                    createdPoolIds: createdPoolIds
                )
                if case .badRequest(let message) = error {
                    throw AppError.validation(message)
                }
                throw AppError.network(error)
            } catch let error as AppError {
                await rollbackLocalInvestmentDraft(
                    newInvestmentIds: newIds,
                    batchId: batch.id,
                    createdPoolIds: createdPoolIds
                )
                throw error
            } catch {
                await self.rollbackLocalInvestmentDraft(
                    newInvestmentIds: newIds,
                    batchId: batch.id,
                    createdPoolIds: createdPoolIds
                )
                throw error.toAppError()
            }
            // Nach Parse-Save (inkl. bookReserve): lokale Salden mit echten Investment-IDs.
            if deferCashDeductions {
                let syncedForBatch = await MainActor.run {
                    repository.investments
                        .filter { $0.batchId == batch.id }
                        .sorted { ($0.sequenceNumber ?? 0) < ($1.sequenceNumber ?? 0) }
                }
                await creationService.applyCashDeductionsAfterBackendSync(
                    investor: investor,
                    batch: batch,
                    investments: syncedForBatch.isEmpty ? investments : syncedForBatch
                )
            }
        }
    }

    /// Entfernt lokal angelegte Zeilen, wenn Parse-Save fehlschlägt (sonst Kontoauszug ohne Server-Hauptbuch).
    private func rollbackLocalInvestmentDraft(
        newInvestmentIds: [String],
        batchId: String,
        createdPoolIds: [String]
    ) async {
        let idSet = Set(newInvestmentIds)
        let poolIdSet = Set(createdPoolIds)
        await MainActor.run {
            for id in newInvestmentIds {
                pendingSyncIds.remove(id)
            }
            repository.investments.removeAll { idSet.contains($0.id) }
            repository.investmentBatches.removeAll { $0.id == batchId }
            if !poolIdSet.isEmpty {
                repository.investmentPools.removeAll { poolIdSet.contains($0.id) }
            }
        }
    }

    // MARK: - Investment Status Management

    func markInvestmentAsActive(for traderId: String) async {
        let updatedInvestment: Investment? = await MainActor.run {
            investmentStatusService.markInvestmentAsActive(
                for: traderId,
                repository: repository,
                investmentPoolLifecycleService: investmentPoolLifecycleService,
                telemetryService: telemetryService
            )
        }
        await syncUpdatedInvestmentToBackend(updatedInvestment)
    }

    func markInvestmentAsCompleted(for traderId: String) async {
        let cashDistributionValues: (Investment, InvestmentReservation)? = await MainActor.run {
            investmentStatusService.markInvestmentAsCompleted(
                for: traderId,
                repository: repository,
                investmentPoolLifecycleService: investmentPoolLifecycleService,
                telemetryService: telemetryService
            )
        }

        Task { await checkAndUpdateInvestmentCompletion() }
        if let (investment, reservation) = cashDistributionValues {
            await distributeCashForCompletion(investment: investment, reservation: reservation)
        }
    }

    func markNextInvestmentAsActive(for investmentId: String) async {
        let updatedInvestment: Investment? = await MainActor.run {
            investmentStatusService.markNextInvestmentAsActive(
                for: investmentId,
                repository: repository,
                investmentPoolLifecycleService: investmentPoolLifecycleService
            )
        }
        await syncUpdatedInvestmentToBackend(updatedInvestment)
    }

    func markActiveInvestmentAsCompleted(for investmentId: String) async {
        let cashDistributionValues: (Investment, InvestmentReservation)? = await MainActor.run {
            investmentStatusService.markActiveInvestmentAsCompleted(
                for: investmentId,
                repository: repository,
                investmentPoolLifecycleService: investmentPoolLifecycleService
            )
        }

        if let (investment, reservation) = cashDistributionValues {
            await distributeCashForCompletion(investment: investment, reservation: reservation)
            await generateCompletionDocument(for: investment)
            await syncUpdatedInvestmentToBackend(investment)
        }

        await checkAndUpdateInvestmentCompletion(for: [investmentId])
    }

    func deleteInvestment(investmentId: String, reservationId: String) async {
        let snapshot = await MainActor.run {
            repository.investments.first { $0.id == investmentId }
        }
        let isLocalOnlyId = UUID(uuidString: investmentId) != nil

        if !isLocalOnlyId, let api = investmentAPIService {
            do {
                try await api.cancelReservedInvestment(investmentId: investmentId)
                let deleted = await MainActor.run {
                    investmentStatusService.deleteInvestment(investmentId: investmentId, repository: repository)
                }
                if deleted {
                    await checkAndUpdateInvestmentCompletion()
                    NotificationCenter.default.post(name: .investorBalanceDidChange, object: nil)
                }
                return
            } catch {
                print("⚠️ InvestmentService: cancelReservedInvestment failed — local fallback: \(error.localizedDescription)")
            }
        }

        if let cash = investorCashBalanceService,
           let inv = snapshot,
           inv.reservationStatus == .reserved {
            await cash.processRemainingBalanceDistribution(
                investorId: inv.investorId,
                amount: inv.amount,
                investmentId: investmentId
            )
        }

        let deleted = await MainActor.run {
            investmentStatusService.deleteInvestment(investmentId: investmentId, repository: repository)
        }

        if deleted {
            await checkAndUpdateInvestmentCompletion()
            NotificationCenter.default.post(name: .investorBalanceDidChange, object: nil)
        }
    }
}
