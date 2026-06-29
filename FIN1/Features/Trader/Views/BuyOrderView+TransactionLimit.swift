import SwiftUI

extension BuyOrderView {

    @MainActor
    func refreshTransactionLimitSnippet(termsContentService: any TermsContentServiceProtocol) async {
        let provider = LegalSnippetProvider(termsContentService: termsContentService)
        let language: TermsOfServiceDataProvider.Language = .german
        let (dailyLimitText, weeklyLimitText, monthlyLimitText): (String?, String?, String?) = {
            guard let result = viewModel.transactionLimitCheckResult else { return (nil, nil, nil) }
            var dailyText: String?
            var weeklyText: String?
            var monthlyText: String?
            for violation in result.violations {
                switch violation {
                case let .dailyLimitExceeded(limit, _, _, _):
                    if dailyText == nil {
                        dailyText = limit.formattedAsLocalizedCurrency()
                    }
                case let .weeklyLimitExceeded(limit, _, _, _):
                    if weeklyText == nil {
                        weeklyText = limit.formattedAsLocalizedCurrency()
                    }
                case let .monthlyLimitExceeded(limit, _, _, _):
                    if monthlyText == nil {
                        monthlyText = limit.formattedAsLocalizedCurrency()
                    }
                }
            }
            return (dailyText, weeklyText, monthlyText)
        }()
        var placeholders: [String: String] = [:]
        if let daily = dailyLimitText {
            placeholders["DAILY_LIMIT"] = daily
        }
        if let weekly = weeklyLimitText {
            placeholders["WEEKLY_LIMIT"] = weekly
        }
        if let monthly = monthlyLimitText {
            placeholders["MONTHLY_LIMIT"] = monthly
        }
        let snippet = await provider.snippet(
            for: .transactionLimitWarningBuy,
            language: language,
            documentType: .terms,
            defaultTitle: "Transaktionslimit erreicht",
            defaultContent: "Ihr (tägliches) Transaktionslimit wurde erreicht oder überschritten.",
            placeholders: placeholders
        )
        self.transactionLimitWarningTitle = snippet.title
        self.transactionLimitIntroText = snippet.content
    }
}
