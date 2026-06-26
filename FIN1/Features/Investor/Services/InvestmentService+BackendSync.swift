import Foundation

extension InvestmentService {
    // MARK: - Backend Sync (Efficient, Lazy)

    /// Syncs pending investments to backend in batch (called on app background).
    func syncToBackend() async {
        if let traderDataService {
            await traderDataService.refreshTraderCatalog()
        }
        try? await self.syncPendingInvestmentsToBackend(propagateFirstFailure: false)
    }

    /// - Parameter propagateFirstFailure: If true, first `saveInvestment` error is rethrown (e.g. user-initiated create).
    func syncPendingInvestmentsToBackend(
        propagateFirstFailure: Bool,
        traderUsername: String? = nil
    ) async throws {
        guard let apiService = investmentAPIService, !pendingSyncIds.isEmpty else { return }

        let idsToSync = pendingSyncIds
        print("📡 InvestmentService: Syncing \(idsToSync.count) investments to backend...")

        let investmentsToSync = await MainActor.run {
            repository.investments.filter { idsToSync.contains($0.id) }
        }

        let batchGroups = Dictionary(grouping: investmentsToSync) { inv -> String in
            if let batchId = inv.batchId, !batchId.isEmpty { return "batch:\(batchId)" }
            return "single:\(inv.id)"
        }

        for (_, group) in batchGroups {
            let sorted = group.sorted { ($0.sequenceNumber ?? 0) < ($1.sequenceNumber ?? 0) }
            let canBatch = sorted.first?.batchId != nil
                && sorted.allSatisfy { ($0.sequenceNumber ?? 0) > 0 }
            let resolvedTraderUsername = sorted.first.map {
                traderUsernameForSync(investment: $0, explicit: traderUsername)
            } ?? traderUsernameForSync(traderId: "", explicit: traderUsername)

            do {
                let savedList: [Investment]
                if canBatch {
                    savedList = try await apiService.saveInvestmentSplits(
                        sorted,
                        traderUsername: resolvedTraderUsername
                    )
                } else {
                    var singles: [Investment] = []
                    for investment in sorted {
                        let splitUsername = traderUsernameForSync(
                            investment: investment,
                            explicit: traderUsername
                        )
                        if investment.batchId != nil, (investment.sequenceNumber ?? 0) > 0 {
                            let saved = try await apiService.saveInvestmentSplits(
                                [investment],
                                traderUsername: splitUsername
                            )
                            guard let first = saved.first else {
                                throw NetworkError.invalidResponse
                            }
                            singles.append(first)
                        } else {
                            singles.append(try await apiService.saveInvestment(investment))
                        }
                    }
                    savedList = singles
                }

                await MainActor.run {
                    for (local, saved) in zip(sorted, savedList) {
                        pendingSyncIds.remove(local.id)
                        if saved.id != local.id,
                           let index = repository.investments.firstIndex(where: { $0.id == local.id }) {
                            repository.investments[index] = saved
                            print("📡 InvestmentService: Updated ID \(local.id) → \(saved.id)")
                        }
                    }
                }
            } catch {
                for investment in sorted {
                    print("⚠️ InvestmentService: Failed to sync batch/split \(investment.id): \(error)")
                }
                if propagateFirstFailure {
                    throw error
                }
            }
        }

        print("✅ InvestmentService: Sync complete, \(pendingSyncIds.count) pending")
    }

    /// Fetches investments from backend and merges status/financial updates into local store.
    func fetchFromBackend(for user: User) async {
        await self.fetchFromBackend(
            canonicalInvestorId: user.canonicalUserId,
            investorIdKeys: user.ledgerUserIdCandidates
        )
    }

    func fetchFromBackend(for investorId: String) async {
        await self.fetchFromBackend(canonicalInvestorId: investorId, investorIdKeys: [investorId])
    }

    func fetchFromBackendForTrader(user: User) async {
        guard user.role == .trader else { return }
        let keys = self.traderIdKeysForBackendSync(user: user)
        await self.fetchFromBackendForTraderIds(keys)
    }

    private func traderIdKeysForBackendSync(user: User) -> [String] {
        var keys = Set<String>()
        let trimmedId = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedId.isEmpty { keys.insert(trimmedId) }
        keys.insert(user.canonicalUserId)

        if let traderDataService,
           let matched = TraderMatchingHelper.findTraderIdForMatching(
               currentUser: user,
               traderDataService: traderDataService
           ),
           !matched.isEmpty {
            keys.insert(matched)
        }

        let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !email.isEmpty { keys.insert(email) }

        return Array(keys)
    }

    private func fetchFromBackendForTraderIds(_ traderIdKeys: [String]) async {
        guard let apiService = investmentAPIService else { return }

        let keys = Array(Set(traderIdKeys.filter { !$0.isEmpty }))
        guard !keys.isEmpty else { return }

        do {
            let remoteInvestments = try await apiService.fetchInvestments(forTraderIds: keys)
            await MainActor.run {
                let keySet = Set(keys.map { $0.lowercased() })
                let remoteIds = Set(remoteInvestments.map(\.id))

                func matchesTraderKeys(_ investment: Investment) -> Bool {
                    let traderKey = investment.traderId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let usernameKey = investment.storedTraderUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return keySet.contains(traderKey)
                        || (!usernameKey.isEmpty && keySet.contains(usernameKey))
                }

                repository.investments.removeAll { inv in
                    guard matchesTraderKeys(inv) else { return false }
                    if pendingSyncIds.contains(inv.id) { return false }
                    return !remoteIds.contains(inv.id)
                }

                let localById = Dictionary(uniqueKeysWithValues: repository.investments.map { ($0.id, $0) })
                var addedCount = 0
                var updatedCount = 0

                for remote in remoteInvestments {
                    let stored = self.enrichTraderUsernameFromCatalogIfNeeded(remote)
                    if let local = localById[stored.id] {
                        let needsUpdate = local.status != stored.status
                            || local.reservationStatus != stored.reservationStatus
                            || abs(local.currentValue - stored.currentValue) > 0.01
                            || abs(local.performance - stored.performance) > 0.01
                            || local.investmentNumber != stored.investmentNumber
                        if needsUpdate {
                            repository.updateInvestment(stored)
                            updatedCount += 1
                        }
                    } else {
                        repository.addInvestment(stored)
                        addedCount += 1
                    }
                }

                print(
                    "📡 InvestmentService: Trader backend sync — \(addedCount) added, \(updatedCount) updated "
                        + "(of \(remoteInvestments.count) remote)"
                )
                NotificationCenter.default.post(name: .investmentStatusUpdated, object: nil)
            }
        } catch {
            print("⚠️ InvestmentService: Trader backend fetch failed: \(error)")
        }
    }

    private func fetchFromBackend(canonicalInvestorId: String, investorIdKeys: [String]) async {
        guard let apiService = investmentAPIService else { return }

        let keys = Array(Set(investorIdKeys.filter { !$0.isEmpty }))
        guard !keys.isEmpty else { return }

        do {
            let remoteInvestments = try await apiService.fetchInvestments(forInvestorIds: keys)
            await MainActor.run {
                let keySet = Set(keys)
                let remoteIds = Set(remoteInvestments.map(\.id))
                repository.investments.removeAll { inv in
                    guard keySet.contains(inv.investorId) else { return false }
                    if pendingSyncIds.contains(inv.id) { return false }
                    return !remoteIds.contains(inv.id)
                }

                let localById = Dictionary(uniqueKeysWithValues: repository.investments.map { ($0.id, $0) })
                var addedCount = 0
                var updatedCount = 0

                for remote in remoteInvestments {
                    var stored = remote.investorId == canonicalInvestorId
                        ? remote
                        : remote.withInvestorId(canonicalInvestorId)
                    stored = self.enrichTraderUsernameFromCatalogIfNeeded(stored)

                    if let local = localById[stored.id] {
                        let partialSellChanged =
                            local.partialSellCount != stored.partialSellCount
                                || local.realizedSellQuantity != stored.realizedSellQuantity
                                || abs(local.realizedSellAmount - stored.realizedSellAmount) > 0.005
                                || local.lastPartialSellAt != stored.lastPartialSellAt
                                || local.tradeSellVolumeProgress != stored.tradeSellVolumeProgress
                                || local.poolTradingAmount != stored.poolTradingAmount
                        let needsUpdate = local.status != stored.status
                            || local.reservationStatus != stored.reservationStatus
                            || abs(local.currentValue - stored.currentValue) > 0.01
                            || abs((local.performance) - (stored.performance)) > 0.01
                            || local.investmentNumber != stored.investmentNumber
                            || local.investorId != stored.investorId
                            || partialSellChanged
                        if needsUpdate {
                            let merged = Investment(
                                id: local.id,
                                investmentNumber: local.investmentNumber ?? stored.investmentNumber,
                                batchId: local.batchId ?? stored.batchId,
                                investorId: stored.investorId,
                                investorName: local.investorName,
                                traderId: local.traderId,
                                traderUsername: local.traderUsername ?? stored.traderUsername,
                                traderName: local.traderName.isEmpty ? stored.traderName : local.traderName,
                                amount: local.amount,
                                currentValue: stored.currentValue,
                                date: local.date,
                                status: stored.status,
                                performance: stored.performance,
                                numberOfTrades: max(local.numberOfTrades, stored.numberOfTrades),
                                sequenceNumber: local.sequenceNumber,
                                createdAt: local.createdAt,
                                updatedAt: stored.updatedAt,
                                completedAt: stored.completedAt ?? local.completedAt,
                                specialization: local.specialization,
                                reservationStatus: stored.reservationStatus,
                                partialSellCount: stored.partialSellCount,
                                realizedSellQuantity: stored.realizedSellQuantity,
                                realizedSellAmount: stored.realizedSellAmount,
                                lastPartialSellAt: stored.lastPartialSellAt,
                                tradeSellVolumeProgress: stored.tradeSellVolumeProgress,
                                poolTradingAmount: stored.poolTradingAmount ?? local.poolTradingAmount
                            )
                            repository.updateInvestment(merged)
                            updatedCount += 1
                        }
                    } else {
                        repository.addInvestment(stored)
                        addedCount += 1
                    }
                }
                print(
                    "📡 InvestmentService: Backend sync — \(addedCount) added, \(updatedCount) updated (of \(remoteInvestments.count) remote)"
                )
            }
        } catch {
            print("⚠️ InvestmentService: Backend fetch failed: \(error)")
        }
    }

    /// Fills `traderUsername` from `TraderDataService` when server row lacks it (legacy pending sync).
    func enrichTraderUsernameFromCatalogIfNeeded(_ investment: Investment) -> Investment {
        guard investment.storedTraderUsername.isEmpty else { return investment }
        guard let traderDataService,
              let trader = traderDataService.getTrader(by: investment.traderId),
              !trader.username.isEmpty else { return investment }
        return investment.withTraderUsername(trader.username)
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

            _ = try await apiService.updateInvestment(investment)
        } catch {
            print("⚠️ InvestmentService: Failed to sync updated investment \(investment.id): \(error)")
        }
    }
}
