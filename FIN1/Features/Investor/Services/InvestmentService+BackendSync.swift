import Foundation

extension InvestmentService {
    // MARK: - Backend Sync (Efficient, Lazy)

    /// Syncs pending investments to backend in batch (called on app background).
    func syncToBackend() async {
        try? await syncPendingInvestmentsToBackend(propagateFirstFailure: false)
    }

    /// - Parameter propagateFirstFailure: If true, first `saveInvestment` error is rethrown (e.g. user-initiated create).
    func syncPendingInvestmentsToBackend(propagateFirstFailure: Bool) async throws {
        guard let apiService = investmentAPIService, !pendingSyncIds.isEmpty else { return }

        let idsToSync = pendingSyncIds
        print("📡 InvestmentService: Syncing \(idsToSync.count) investments to backend...")

        let investmentsToSync = await MainActor.run {
            repository.investments.filter { idsToSync.contains($0.id) }
        }

        for investment in investmentsToSync {
            do {
                let savedInvestment = try await apiService.saveInvestment(investment)
                let localId = investment.id
                await MainActor.run {
                    pendingSyncIds.remove(localId)
                    if savedInvestment.id != localId,
                       let index = repository.investments.firstIndex(where: { $0.id == localId }) {
                        repository.investments[index] = savedInvestment
                        print("📡 InvestmentService: Updated ID \(localId) → \(savedInvestment.id)")
                    }
                }
            } catch {
                print("⚠️ InvestmentService: Failed to sync investment \(investment.id): \(error)")
                if propagateFirstFailure {
                    throw error
                }
            }
        }

        print("✅ InvestmentService: Sync complete, \(pendingSyncIds.count) pending")
    }

    /// Fetches investments from backend and merges status/financial updates into local store.
    func fetchFromBackend(for investorId: String) async {
        guard let apiService = investmentAPIService else { return }

        do {
            let remoteInvestments = try await apiService.fetchInvestments(for: investorId)
            await MainActor.run {
                let remoteIds = Set(remoteInvestments.map(\.id))
                repository.investments.removeAll { inv in
                    guard inv.investorId == investorId else { return false }
                    if pendingSyncIds.contains(inv.id) { return false }
                    return !remoteIds.contains(inv.id)
                }

                let localById = Dictionary(uniqueKeysWithValues: repository.investments.map { ($0.id, $0) })
                var addedCount = 0
                var updatedCount = 0

                for remote in remoteInvestments {
                    if let local = localById[remote.id] {
                        let partialSellChanged =
                            local.partialSellCount != remote.partialSellCount
                            || local.realizedSellQuantity != remote.realizedSellQuantity
                            || abs(local.realizedSellAmount - remote.realizedSellAmount) > 0.005
                            || local.lastPartialSellAt != remote.lastPartialSellAt
                            || local.tradeSellVolumeProgress != remote.tradeSellVolumeProgress
                        let needsUpdate = local.status != remote.status
                            || local.reservationStatus != remote.reservationStatus
                            || abs(local.currentValue - remote.currentValue) > 0.01
                            || abs((local.performance) - (remote.performance)) > 0.01
                            || local.investmentNumber != remote.investmentNumber
                            || partialSellChanged
                        if needsUpdate {
                            let merged = Investment(
                                id: local.id,
                                investmentNumber: local.investmentNumber ?? remote.investmentNumber,
                                batchId: local.batchId ?? remote.batchId,
                                investorId: local.investorId,
                                investorName: local.investorName,
                                traderId: local.traderId,
                                traderName: local.traderName.isEmpty ? remote.traderName : local.traderName,
                                amount: local.amount,
                                currentValue: remote.currentValue,
                                date: local.date,
                                status: remote.status,
                                performance: remote.performance,
                                numberOfTrades: max(local.numberOfTrades, remote.numberOfTrades),
                                sequenceNumber: local.sequenceNumber,
                                createdAt: local.createdAt,
                                updatedAt: remote.updatedAt,
                                completedAt: remote.completedAt ?? local.completedAt,
                                specialization: local.specialization,
                                reservationStatus: remote.reservationStatus,
                                partialSellCount: remote.partialSellCount,
                                realizedSellQuantity: remote.realizedSellQuantity,
                                realizedSellAmount: remote.realizedSellAmount,
                                lastPartialSellAt: remote.lastPartialSellAt,
                                tradeSellVolumeProgress: remote.tradeSellVolumeProgress
                            )
                            repository.updateInvestment(merged)
                            updatedCount += 1
                        }
                    } else {
                        repository.addInvestment(remote)
                        addedCount += 1
                    }
                }
                print("📡 InvestmentService: Backend sync — \(addedCount) added, \(updatedCount) updated (of \(remoteInvestments.count) remote)")
            }
        } catch {
            print("⚠️ InvestmentService: Backend fetch failed: \(error)")
        }
    }

    /// Marks an investment for sync (called after local creation).
    func markForSync(_ investmentId: String) {
        pendingSyncIds.insert(investmentId)
    }

    /// Write-through sync for local status transitions (reserved -> active -> completed).
    func syncUpdatedInvestmentToBackend(_ investment: Investment?) async {
        guard let investment, let apiService = investmentAPIService else { return }
        do {
            if investment.reservationStatus == .active {
                do {
                    try await apiService.activateReservedInvestment(investmentId: investment.id)
                    return
                } catch {
                    print("⚠️ InvestmentService: activateReservedInvestment failed for \(investment.id), fallback to update: \(error)")
                    if UUID(uuidString: investment.id) == nil {
                        _ = try await apiService.updateInvestment(investment)
                        return
                    }
                }
            }

            if UUID(uuidString: investment.id) == nil {
                _ = try await apiService.updateInvestment(investment)
            } else {
                _ = try await apiService.saveInvestment(investment)
            }
        } catch {
            print("⚠️ InvestmentService: Failed to sync updated investment \(investment.id): \(error)")
        }
    }
}
