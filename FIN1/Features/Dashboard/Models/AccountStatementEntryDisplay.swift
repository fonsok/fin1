import Foundation

// MARK: - Account Statement Entry Display Helpers
/// Extension providing human-readable descriptions for account statement entries
extension AccountStatementEntry {

    // MARK: - Description Title

    /// Human‑readable primary description so users clearly see
    /// where cash is going to or coming from.
    var descriptionTitle: String {
        switch category {
        case .investment:
            return investmentDescriptionTitle
        case .walletDeposit:
            return "Einzahlung"
        case .walletWithdrawal:
            return "Auszahlung"
        case .serviceCharge:
            return serviceChargeDescriptionTitle
        case .profitDistribution:
            return profitDistributionDescriptionTitle
        case .remainingBalance:
            return remainingBalanceDescriptionTitle
        case .tradeSettlement:
            return tradeSettlementDescriptionTitle
        case .commission:
            return commissionDescriptionTitle
        case .adjustment:
            return "Account adjustment"
        case .other:
            return title
        }
    }

    // MARK: - Description Subtitle

    /// Optional secondary line that explains the cash movement in plain language.
    var descriptionSubtitle: String? {
        switch category {
        case .investment:
            return investmentDescriptionSubtitle
        case .walletDeposit:
            return "Geldeingang von Ihrem Referenzkonto auf Ihr \(AppBrand.appName)-Wallet."
        case .walletWithdrawal:
            return "Geldausgang von Ihrem \(AppBrand.appName)-Wallet auf Ihr Referenzkonto."
        case .serviceCharge:
            return serviceChargeDescriptionSubtitle
        case .profitDistribution:
            return profitDistributionDescriptionSubtitle
        case .remainingBalance:
            return remainingBalanceDescriptionSubtitle
        case .tradeSettlement:
            return tradeSettlementDescriptionSubtitle
        case .commission:
            return commissionDescriptionSubtitle
        case .adjustment:
            return "Manual accounting adjustment applied to your cash balance."
        case .other:
            return subtitle
        }
    }

    // MARK: - Private Title Helpers

    private var investmentDescriptionTitle: String {
        let investmentId = metadata["investmentId"] ?? reference
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
        let investmentId = metadata["investmentId"] ?? reference
        if let investmentId {
            return "Platform service charge for Investment \(investmentId)"
        }
        return "Platform service charge"
    }

    private var profitDistributionDescriptionTitle: String {
        let investmentId = metadata["investmentId"] ?? reference
        if let investmentId, !investmentId.isEmpty {
            return "Profit distribution from Investment \(investmentId)"
        }
        return "Profit distribution"
    }

    private var remainingBalanceDescriptionTitle: String {
        let investmentId = metadata["investmentId"] ?? reference
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
            return traderCommissionTitle
        } else {
            return investorCommissionTitle
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
        let investmentId = metadata["investmentId"] ?? reference
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
        let investmentId = metadata["investmentId"] ?? reference
        let isRefundableFlag = metadata["isRefundable"] ?? "false"
        let refundableText = isRefundableFlag == "true" ? "refundable fee" : "non‑refundable fee"
        if let investmentId {
            return "Platform fee for Investment \(investmentId) (\(refundableText))."
        }
        return "Platform service fee (\(refundableText))."
    }

    private var profitDistributionDescriptionSubtitle: String? {
        let investmentId = metadata["investmentId"] ?? reference
        if let investmentId, !investmentId.isEmpty {
            return "Cash inflow from realized profits on Investment \(investmentId)."
        }
        return "Cash inflow from realized profits on your investments."
    }

    private var remainingBalanceDescriptionSubtitle: String? {
        let investmentId = metadata["investmentId"] ?? reference
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
            return traderCommissionSubtitle
        } else {
            return investorCommissionSubtitle
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











