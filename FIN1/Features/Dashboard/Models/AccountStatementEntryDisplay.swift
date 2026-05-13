import Foundation

// MARK: - Account Statement Entry Display Helpers
/// Extension providing human-readable descriptions for account statement entries
extension AccountStatementEntry {
    var resolvedReferenceDocumentNumber: String? {
        if let referenceDocumentNumber, !referenceDocumentNumber.isEmpty {
            return referenceDocumentNumber
        }
        if let fromMetadata = metadata["referenceDocumentNumber"], !fromMetadata.isEmpty {
            return fromMetadata
        }
        if let fromMetadata = metadata["accountingDocumentNumber"], !fromMetadata.isEmpty {
            return fromMetadata
        }
        return nil
    }

    private func appendDocumentNumber(to base: String?) -> String? {
        guard let docNo = resolvedReferenceDocumentNumber, !docNo.isEmpty else {
            return base
        }
        let suffix = "Belegnr.: \(docNo)"
        guard let base, !base.isEmpty else {
            return suffix
        }
        if base.contains("Belegnr.:") {
            return base
        }
        return "\(base) · \(suffix)"
    }
    /// Prefer backend business number (INV-YYYY-xxxxx) when present; otherwise
    /// normalize UUID/objectId style references to a stable short INV label.
    private var preferredInvestmentReference: String? {
        let rawReference = metadata["businessReference"] ?? metadata["investmentNumber"] ?? metadata["investmentId"] ?? reference
        guard let rawReference, !rawReference.isEmpty else { return nil }
        if rawReference.uppercased().hasPrefix("INV-") {
            return rawReference
        }
        let compact = rawReference
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard !compact.isEmpty else { return rawReference }
        return "INV-\(String(compact.prefix(8)))"
    }

    // MARK: - Description Title

    /// Human‑readable primary description so users clearly see
    /// where cash is going to or coming from.
    var descriptionTitle: String {
        switch category {
        case .investment:
            return self.investmentDescriptionTitle
        case .walletDeposit:
            return "Einzahlung"
        case .walletWithdrawal:
            return "Auszahlung"
        case .serviceCharge:
            return self.serviceChargeDescriptionTitle
        case .profitDistribution:
            return self.profitDistributionDescriptionTitle
        case .remainingBalance:
            return self.remainingBalanceDescriptionTitle
        case .tradeSettlement:
            return self.tradeSettlementDescriptionTitle
        case .commission:
            return self.commissionDescriptionTitle
        case .adjustment:
            return "Account adjustment"
        case .other:
            return title
        }
    }

    // MARK: - Description Subtitle

    /// Optional secondary line that explains the cash movement in plain language.
    var descriptionSubtitle: String? {
        let base: String?
        switch category {
        case .investment:
            base = self.investmentDescriptionSubtitle
        case .walletDeposit:
            base = "Geldeingang von Ihrem Referenzkonto auf Ihr \(AppBrand.appName)-Wallet."
        case .walletWithdrawal:
            base = "Geldausgang von Ihrem \(AppBrand.appName)-Wallet auf Ihr Referenzkonto."
        case .serviceCharge:
            base = self.serviceChargeDescriptionSubtitle
        case .profitDistribution:
            base = self.profitDistributionDescriptionSubtitle
        case .remainingBalance:
            base = self.remainingBalanceDescriptionSubtitle
        case .tradeSettlement:
            base = self.tradeSettlementDescriptionSubtitle
        case .commission:
            base = self.commissionDescriptionSubtitle
        case .adjustment:
            base = "Manual accounting adjustment applied to your cash balance."
        case .other:
            base = subtitle
        }
        return self.appendDocumentNumber(to: base)
    }

    // MARK: - Private Title Helpers

    private var investmentDescriptionTitle: String {
        let investmentId = self.preferredInvestmentReference
        if direction == .debit {
            if let investmentId {
                return "Reserved for Investment \(investmentId)"
            }
            return "Cash reserved for investment"
        } else {
            if let investmentId {
                return "Returned from Investment \(investmentId)"
            }
            return "Cash returned from investment"
        }
    }

    private var serviceChargeDescriptionTitle: String {
        let investmentId = self.preferredInvestmentReference
        if let investmentId {
            return "App service charge for Investment \(investmentId)"
        }
        return "App service charge"
    }

    private var profitDistributionDescriptionTitle: String {
        let investmentId = self.preferredInvestmentReference
        if let investmentId, !investmentId.isEmpty {
            return "Profit distribution from Investment \(investmentId)"
        }
        return "Profit distribution"
    }

    private var remainingBalanceDescriptionTitle: String {
        let investmentId = self.preferredInvestmentReference
        if let investmentId, !investmentId.isEmpty {
            return "Remaining balance distribution from Investment \(investmentId)"
        }
        return "Remaining balance distribution"
    }

    private var tradeSettlementDescriptionTitle: String {
        let wknOrIsin = metadata["wknOrIsin"]
        let underlying = metadata["underlyingAsset"]
        let directionLabel = metadata["securitiesDirection"] ?? metadata["transactionType"]
        let tradeDirection = directionLabel?.isEmpty == false ? directionLabel : (direction == .credit ? "Verkauf" : "Kauf")

        var components: [String] = []
        if let wknOrIsin, !wknOrIsin.isEmpty {
            components.append(wknOrIsin)
        }
        if let underlying, !underlying.isEmpty {
            components.append(underlying)
        }
        let baseInstrument = components.isEmpty ? nil : components.joined(separator: " · ")

        if let baseInstrument {
            return "\(tradeDirection ?? "") \(baseInstrument)"
        } else {
            let base = title.isEmpty ? "Trade settlement" : title
            return "\(base) (\(direction == .credit ? "cash inflow" : "cash outflow"))"
        }
    }

    private var commissionDescriptionTitle: String {
        if direction == .credit {
            return self.traderCommissionTitle
        } else {
            return self.investorCommissionTitle
        }
    }

    private var traderCommissionTitle: String {
        var titleParts: [String] = ["Gutschrift Provision"]
        if let tradeNumber = metadata["tradeNumber"], !tradeNumber.isEmpty {
            titleParts.append("Trade #\(tradeNumber)")
        } else if let tradeNumbers = metadata["tradeNumbers"], !tradeNumbers.isEmpty {
            let formattedNumbers = tradeNumbers.split(separator: ",").map { "#\($0.trimmingCharacters(in: .whitespaces))" }
            titleParts.append("Trades \(formattedNumbers.joined(separator: ", "))")
        }
        return titleParts.joined(separator: " · ")
    }

    private var investorCommissionTitle: String {
        var titleParts: [String] = ["Commission"]
        if let seqNum = metadata["investmentSequenceNumber"] {
            titleParts.append("Investment #\(seqNum)")
        }
        if let traderName = metadata["traderName"], !traderName.isEmpty {
            if let tradeNumbers = metadata["tradeNumbers"], !tradeNumbers.isEmpty {
                titleParts.append("\(traderName): Trade \(tradeNumbers)")
            } else {
                titleParts.append(traderName)
            }
        } else if let tradeNumbers = metadata["tradeNumbers"], !tradeNumbers.isEmpty {
            titleParts.append("Trade \(tradeNumbers)")
        }
        return titleParts.joined(separator: " · ")
    }

    // MARK: - Private Subtitle Helpers

    private var investmentDescriptionSubtitle: String? {
        let investmentId = self.preferredInvestmentReference
        if direction == .debit {
            if let investmentId {
                return "Cash moved out of available balance and locked for Investment \(investmentId)."
            }
            return "Cash moved out of available balance and locked for an investment."
        } else {
            if let investmentId {
                return "Cash released back from Investment \(investmentId) into your available balance."
            }
            return "Cash released back from an investment into your available balance."
        }
    }

    private var serviceChargeDescriptionSubtitle: String? {
        let investmentId = self.preferredInvestmentReference
        let isRefundableFlag = metadata["isRefundable"] ?? "false"
        let refundableText = isRefundableFlag == "true" ? "refundable fee" : "non‑refundable fee"
        if let investmentId {
            return "App fee for Investment \(investmentId) (\(refundableText))."
        }
        return "App service fee (\(refundableText))."
    }

    private var profitDistributionDescriptionSubtitle: String? {
        let investmentId = self.preferredInvestmentReference
        if let investmentId, !investmentId.isEmpty {
            return "Cash inflow from realized profits on Investment \(investmentId)."
        }
        return "Cash inflow from realized profits on your investments."
    }

    private var remainingBalanceDescriptionSubtitle: String? {
        let investmentId = self.preferredInvestmentReference
        if let investmentId, !investmentId.isEmpty {
            return "Cash returned from Investment \(investmentId) after cancellation or deletion."
        }
        return "Cash returned from unused or remaining investment balance."
    }

    private var tradeSettlementDescriptionSubtitle: String? {
        let transactionType = metadata["transactionType"] ?? (direction == .credit ? "sell" : "buy")
        let wknOrIsin = metadata["wknOrIsin"]
        let issuer = metadata["issuer"]
        let underlying = metadata["underlyingAsset"]
        let strike = metadata["strikePrice"]
        let quantity = metadata["quantity"]
        let tradeNumber = metadata["tradeNumber"]

        var detailsParts: [String] = []
        if let wknOrIsin, !wknOrIsin.isEmpty {
            detailsParts.append("WKN/ISIN: \(wknOrIsin)")
        }
        if let issuer, !issuer.isEmpty {
            detailsParts.append("Emittent: \(issuer)")
        }
        if let underlying, !underlying.isEmpty {
            detailsParts.append("Basiswert: \(underlying)")
        }
        if let strike, !strike.isEmpty {
            detailsParts.append("Strike: \(strike)")
        }
        if let quantity, !quantity.isEmpty {
            detailsParts.append("Stückzahl: \(quantity)")
        }
        if let tradeNumber, !tradeNumber.isEmpty {
            detailsParts.append("Trade-Nr.: \(tradeNumber)")
        } else if let subtitle, !subtitle.isEmpty {
            detailsParts.append(subtitle)
        }

        let directionText = direction == .credit ? "Geldeingang" : "Geldausgang"
        let baseSentence = "\(directionText) aus \(transactionType.uppercased())-Abrechnung."

        if detailsParts.isEmpty {
            return baseSentence
        } else {
            let joinedDetails = detailsParts.joined(separator: " · ")
            return "\(baseSentence) \(joinedDetails)"
        }
    }

    private var commissionDescriptionSubtitle: String? {
        if direction == .credit {
            return self.traderCommissionSubtitle
        } else {
            return self.investorCommissionSubtitle
        }
    }

    private var traderCommissionSubtitle: String? {
        var detailsParts: [String] = []

        if let commissionAmountStr = metadata["commissionAmount"],
           let commissionAmount = Double(commissionAmountStr) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "EUR"
            formatter.locale = Locale(identifier: "de_DE")
            if let formatted = formatter.string(from: NSNumber(value: commissionAmount)) {
                detailsParts.append("Provision: \(formatted)")
            }
        }

        if detailsParts.isEmpty {
            return "Trader-Provision aus Handelsabrechnung."
        } else {
            return "Trader-Provision aus Handelsabrechnung. \(detailsParts.joined(separator: " · "))"
        }
    }

    private var investorCommissionSubtitle: String? {
        var detailsParts: [String] = []

        if let grossProfitStr = metadata["grossProfit"],
           let grossProfit = Double(grossProfitStr) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "EUR"
            formatter.locale = Locale(identifier: "de_DE")
            if let formatted = formatter.string(from: NSNumber(value: grossProfit)) {
                detailsParts.append("Bruttogewinn: \(formatted)")
            }
        }

        if let rateStr = metadata["commissionRate"] {
            detailsParts.append("Provision: \(rateStr)%")
        }

        if detailsParts.isEmpty {
            return "Commission deducted according to the current fee schedule."
        } else {
            return detailsParts.joined(separator: " · ")
        }
    }
}











