import Foundation

extension InvestmentService {
    // MARK: - Investment Creation

    func createInvestment(
        investor: User,
        trader: InvestorTrader,
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
                try await syncPendingInvestmentsToBackend(
                    propagateFirstFailure: true,
                    traderUsername: trader.username
                )
            } catch {
                var syncResolved = false
                if Self.isDuplicateInvestmentSyncError(error) {
                    syncResolved = await self.reconcileInvestmentBatchFromBackend(
                        batchId: batch.id,
                        localIds: newIds
                    )
                    if !syncResolved {
                        do {
                            try await syncPendingInvestmentsToBackend(
                                propagateFirstFailure: true,
                                traderUsername: trader.username
                            )
                            syncResolved = true
                        } catch {
                            syncResolved = await self.reconcileInvestmentBatchFromBackend(
                                batchId: batch.id,
                                localIds: newIds
                            )
                            if !syncResolved {
                                await self.rollbackLocalInvestmentDraft(
                                    newInvestmentIds: newIds,
                                    batchId: batch.id,
                                    createdPoolIds: createdPoolIds
                                )
                                throw Self.investmentSyncErrorAsAppError(error)
                            }
                        }
                    }
                    print("✅ InvestmentService: Batch \(batch.id) nach Duplicate/Reconcile übernommen")
                } else {
                    await self.rollbackLocalInvestmentDraft(
                        newInvestmentIds: newIds,
                        batchId: batch.id,
                        createdPoolIds: createdPoolIds
                    )
                    throw Self.investmentSyncErrorAsAppError(error)
                }
            }
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

    private static func isDuplicateInvestmentSyncError(_ error: Error) -> Bool {
        let text: String
        if let appError = error as? AppError, case .network(let net) = appError {
            if case .badRequest(let message) = net {
                text = message
            } else {
                return false
            }
        } else if let net = error as? NetworkError, case .badRequest(let message) = net {
            text = message
        } else {
            return false
        }
        let lower = text.lowercased()
        return lower.contains("duplicate")
            || lower.contains("kollidiert")
            || lower.contains("bereits angelegt")
    }

    private static func investmentSyncErrorAsAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if let networkError = error as? NetworkError {
            if case .badRequest(let message) = networkError {
                return AppError.validation(message)
            }
            return AppError.network(networkError)
        }
        return error.toAppError()
    }

    /// Nach Timeout/Duplicate: Splits am Server per batchId+sequenceNumber laden und lokale UUIDs ersetzen.
    private func reconcileInvestmentBatchFromBackend(batchId: String, localIds: [String]) async -> Bool {
        guard let apiService = investmentAPIService else { return false }

        let locals: [Investment] = await MainActor.run {
            repository.investments.filter { $0.batchId == batchId && localIds.contains($0.id) }
        }
        guard !locals.isEmpty else { return false }

        let investorId = locals[0].investorId
        do {
            let remote = try await apiService.fetchInvestments(for: investorId)
            let remoteForBatch = remote.filter { $0.batchId == batchId }
            let localSeq = Set(locals.compactMap(\.sequenceNumber))
            let remoteSeq = Set(remoteForBatch.compactMap(\.sequenceNumber))
            guard localSeq.isSubset(of: remoteSeq) else { return false }

            await MainActor.run {
                for local in locals {
                    guard let seq = local.sequenceNumber,
                          let match = remoteForBatch.first(where: { $0.sequenceNumber == seq }),
                          abs(match.amount - local.amount) <= 0.01 else { continue }
                    pendingSyncIds.remove(local.id)
                    if let index = repository.investments.firstIndex(where: { $0.id == local.id }) {
                        repository.investments[index] = match
                    }
                }
            }

            let stillPending = await MainActor.run {
                localIds.filter { pendingSyncIds.contains($0) }
            }
            return stillPending.isEmpty
        } catch {
            print("⚠️ InvestmentService: reconcileInvestmentBatchFromBackend failed: \(error)")
            return false
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
