import Foundation

/// FAQ data provider containing all FAQ content
struct FAQDataProvider {
    /// NOTE: Must be `var` (computed) so AppBrand.appName is evaluated at access time, not static init.
    static var allFAQs: [FAQItem] { [
        // MARK: - Investments
        FAQItem(
            id: "inv-1",
            question: "How does an investor invest in a trader?",
            answer: "Navigate to the Dashboard, browse available traders, and tap on a trader to view their profile. From there, you can tap 'Invest' to create an investment. You'll be able to set your investment amount and choose between a single investment or multiple investments strategy. (Multiple investments strategy: In order to avoid a 100% risk of loss, the risk should be spread across several investments)",
            category: .investments
        ),
        FAQItem(
            id: "inv-3",
            question: "What is the minimum investment amount?",
            answer: "The minimum investment amount varies depending on the trader and their requirements. You'll see the minimum amount when viewing a trader's profile. Generally, minimum investments start from a reasonable amount to ensure accessibility.",
            category: .investments
        ),
        FAQItem(
            id: "inv-4",
            question: "How are profits and losses calculated?",
            answer: "Profits and losses are calculated proportionally based on your investment share in each pool. If a pool generates a profit, you receive a percentage equal to your investment share. Similarly, losses are shared proportionally among all investors in that pool.",
            category: .investments
        ),
        FAQItem(
            id: "inv-5",
            question: "Can I withdraw my investment?",
            answer: "Investment withdrawal depends on the specific terms of your investment agreement and the trader's policies. Active investments typically cannot be withdrawn until completion. Please check your investment details or contact support for specific withdrawal options.",
            category: .investments
        ),
        FAQItem(
            id: "inv-6",
            question: "How do I track my investment performance?",
            answer: "You can view your investment performance in the Portfolio section. The dashboard shows your active investments, completed investments, total portfolio value, profit/loss, and performance metrics over different time periods.",
            category: .investments
        ),
        FAQItem(
            id: "inv-7",
            question: "How do I choose which trader to invest with?",
            answer: "Use the Investor Discovery section to browse traders, view performance metrics (returns, win rate), specialization, risk level, and minimum investment requirements. You can add traders to your watchlist for later review.",
            category: .investments
        ),
        FAQItem(
            id: "inv-8",
            question: "How are profits calculated and distributed?",
            answer: "When a trader completes a trade (both buy and sell executed), profits are calculated after fees. Each investor receives a proportional share based on their investment amount relative to the total pool size.",
            category: .investments
        ),
        FAQItem(
            id: "inv-9",
            question: "Is my investment guaranteed?",
            answer: "No. \(AppBrand.appName) does not guarantee returns. All investments carry risk, and you can lose your invested capital. Only invest what you can afford to lose.\n Note: please do not invest more than 2% of your assets.",
            category: .investments
        ),
        FAQItem(
            id: "inv-10",
            question: "Can I lose more than I invest?",
            answer: "Your maximum loss is limited to your invested amount. You cannot lose more than you've invested in a pool.",
            category: .investments
        ),
        FAQItem(
            id: "inv-11",
            question: "Are there fees to use \(AppBrand.appName)?",
            answer: "Trading fees apply per trade (order fees, exchange fees, foreign transaction costs if applicable). All fees are disclosed before you confirm any transaction. Check the current fee schedule in your account settings.",
            category: .investments
        ),

        // MARK: - Trading
        FAQItem(
            id: "trd-1",
            question: "How do I execute a trade?",
            answer: "As a trader, navigate to the Trading section. You can create buy or sell orders for securities. Select the security, enter the quantity and price, review the trade details, and confirm. The trade will be executed using the pooled capital from your investors.",
            category: .trading
        ),
        FAQItem(
            id: "trd-2",
            question: "What securities can I trade?",
            answer: "You can trade various securities including stocks, options, and other financial instruments. Use the securities search feature to find available instruments by WKN, ISIN, or name. The available securities depend on market access and your account permissions.",
            category: .trading
        ),
        FAQItem(
            id: "trd-3",
            question: "How are trading fees calculated?",
            answer: "Trading fees are calculated based on the trade type and size. Buy orders typically have different fee structures than sell orders. Fees are automatically calculated and displayed before trade confirmation. Detailed fee breakdowns are available in trade details and invoices.",
            category: .trading
        ),
        FAQItem(
            id: "trd-4",
            question: "What is a trade number?",
            answer: "Each trade is assigned a unique trade number for tracking and reference. Trade numbers help you identify specific trades in your trading history, invoices, and account statements. They are automatically generated when a trade is created.",
            category: .trading
        ),
        FAQItem(
            id: "trd-5",
            question: "Can I cancel a trade?",
            answer: "Trades can typically be cancelled if they haven't been executed yet. Once a trade is executed, it cannot be cancelled. Check your order status in the Trading section. If you need to reverse a completed trade, you may need to execute an opposite trade.",
            category: .trading
        ),
        FAQItem(
            id: "trd-6",
            question: "What is the Depot and how does it work?",
            answer: "The Depot is your trading portfolio where you can view all your holdings and ongoing orders. It shows your depot value, depot number, active orders that are being processed, and completed positions (holdings). The Depot is the central place to monitor all your trading activity and positions.",
            category: .trading
        ),
        FAQItem(
            id: "trd-7",
            question: "What are ongoing orders (Laufende Orders)?",
            answer: "Ongoing orders are buy or sell orders that have been submitted but not yet completed. They appear in the 'Laufende Orders' section of your Depot. Once an order is executed and completed, it moves from ongoing orders to your holdings (Bestand) section.",
            category: .trading
        ),
        FAQItem(
            id: "trd-8",
            question: "What are holdings (Bestand) in my Depot?",
            answer: "Holdings are completed positions in your Depot. When a buy order is completed, the position appears in your holdings. Holdings show the security details, quantity, purchase price, current value, and profit/loss. You can sell holdings by creating a sell order.",
            category: .trading
        ),
        FAQItem(
            id: "trd-9",
            question: "How is my depot value calculated?",
            answer: "Your depot value is calculated based on the current market value of all your holdings. It includes both realized and unrealized profits/losses. The value updates as market prices change and reflects the total value of all positions in your depot.",
            category: .trading
        ),
        FAQItem(
            id: "trd-10",
            question: "How do I view details of a holding?",
            answer: "Tap on any holding in the 'Bestand' section of your Depot to view detailed information including the security details, purchase price, current value, profit/loss, and position number. For options and warrants, you can also view underlying information and strike details.",
            category: .trading
        ),
        FAQItem(
            id: "trd-11",
            question: "What happens when I sell a holding?",
            answer: "When you create a sell order for a holding, it first appears in your ongoing orders. Once the sell order is executed and confirmed, the position is removed from your holdings, and the profit/loss is calculated. You'll see a success confirmation overlay showing the trade details.",
            category: .trading
        ),

        // MARK: - Portfolio & Performance
        FAQItem(
            id: "port-1",
            question: "How is my portfolio value calculated?",
            answer: "Your portfolio value is calculated by summing the current value of all your active investments, including any unrealized profits or losses. The value updates based on the performance of the pools you're invested in and current market conditions.",
            category: .portfolio
        ),
        FAQItem(
            id: "port-2",
            question: "What timeframes can I view performance for?",
            answer: "You can view your portfolio performance for different timeframes including 1 week, 1 month, 3 months, 6 months, 1 year, and all time. Select your preferred timeframe in the Portfolio section to see performance metrics and historical data.",
            category: .portfolio
        ),
        FAQItem(
            id: "port-3",
            question: "How do I view my investment history?",
            answer: "Navigate to the Portfolio section and select 'Completed Investments' to view your investment history. You can see details about past investments including final returns, duration, and performance metrics.",
            category: .portfolio
        ),
        FAQItem(
            id: "port-4",
            question: "What is the difference between active and completed investments?",
            answer: "Active investments are currently ongoing, where your funds are automatically being managed. Completed investments have been closed, and final profits/losses have been calculated and distributed. You can view both types in your Portfolio section.",
            category: .portfolio
        ),

        // MARK: - Invoices & Statements
        FAQItem(
            id: "invst-1",
            question: "How do I view my invoices?",
            answer: "Invoices are available in the Documents section of Profile -> Notifications. You'll receive invoices for trades, fees, and other transactions. Monthly account statements are automatically generated and include all transactions for that period.",
            category: .invoices
        ),
        FAQItem(
            id: "invst-2",
            question: "When are monthly statements generated?",
            answer: "Monthly account statements are automatically generated at the end of each month. You'll receive a notification when your statement is ready. Statements include all transactions, balances, and activity for that month.",
            category: .invoices
        ),
        FAQItem(
            id: "invst-3",
            question: "What information is included in an invoice?",
            answer: "Invoices include trade details (trade number, security, quantity, price), fees, taxes, net amounts, and transaction dates.",
            category: .invoices
        ),
        FAQItem(
            id: "invst-4",
            question: "Can I download my invoices and statements?",
            answer: "Yes, you can download invoices and statements from the Profile -> Notifications -> Documents section. Tap on any document to view details, and use the download option to save it to your device or share it.",
            category: .invoices
        ),

        // MARK: - Security & Authentication
        FAQItem(
            id: "sec-1",
            question: "How do I enable Face ID or Touch ID?",
            answer: "Face ID and Touch ID can be enabled in your device settings and will be available if your device supports biometric authentication. The app will prompt you to use biometric authentication when logging in if it's enabled on your device.",
            category: .security
        ),
        FAQItem(
            id: "sec-2",
            question: "What should I do if I forget my password?",
            answer: "On the login screen, tap 'Forgot Password' to reset your password. You'll receive an email with instructions to create a new password. Make sure to use a strong password with a mix of letters, numbers, and special characters.",
            category: .security
        ),
        FAQItem(
            id: "sec-3",
            question: "How secure is my data?",
            answer: "We use industry-standard security measures including AES-256 encryption for sensitive data, TLS 1.3 for network communication, and secure storage via Keychain. Your data is protected and we comply with GDPR regulations for data privacy.",
            category: .security
        ),
        FAQItem(
            id: "sec-4",
            question: "Can I change my password?",
            answer: "Yes, you can change your password in the Settings section under Security. You'll need to enter your current password and create a new one. Make sure your new password meets the security requirements.",
            category: .security
        ),

        // MARK: - Notifications
        FAQItem(
            id: "notif-1",
            question: "How do I manage my notifications?",
            answer: "Go to Profile select Notifications to manage your notification.",
            category: .notifications
        ),
        FAQItem(
            id: "notif-2",
            question: "What types of notifications will I receive?",
            answer: "You'll receive notifications for important events such as new trades, investment updates, document availability (invoices, statements), account changes, and security alerts.",
            category: .notifications
        ),
        FAQItem(
            id: "notif-3",
            question: "How do I view my notification history?",
            answer: "Tap the Notifications button in your Profile to view all notifications. Unread notifications are marked with a badge. You can mark notifications as read and filter them by type or date.",
            category: .notifications
        ),

        // MARK: - Technical Support
        FAQItem(
            id: "tech-1",
            question: "The app is running slowly. What should I do?",
            answer: "Try closing and reopening the app, or restart your device. Make sure you have a stable internet connection. If the issue persists, check for app updates in the App Store, or contact our support team for assistance.",
            category: .technical
        ),
        FAQItem(
            id: "tech-2",
            question: "I'm experiencing connection issues. How can I fix this?",
            answer: "Check your internet connection and try switching between Wi-Fi and mobile data. Ensure the app has network permissions enabled in your device settings. If problems continue, contact support with details about when the issue occurs.",
            category: .technical
        ),
        FAQItem(
            id: "tech-3",
            question: "How do I update the app?",
            answer: "App updates are available through the App Store. Go to the App Store, search for \(AppBrand.appName), and tap 'Update' if an update is available. We recommend keeping the app updated to access the latest features and security improvements.",
            category: .technical
        ),
        FAQItem(
            id: "tech-4",
            question: "The app crashed. What should I do?",
            answer: "Try restarting the app. If crashes persist, try restarting your device or reinstalling the app (your data is stored securely on our servers). If the problem continues, contact support and provide details about when the crash occurred and what you were doing.",
            category: .technical
        ),
        FAQItem(
            id: "tech-5",
            question: "How do I contact support?",
            answer: "You can contact support through the Profile section by tapping 'Contact Support' in the Support & Legal section. You can also email our support team directly. We typically respond within 24-48 hours during business days.",
            category: .technical
        )
    ] }

    /// Get FAQs filtered by category
    static func faqs(for category: FAQCategory) -> [FAQItem] {
        allFAQs.filter { $0.category == category }
    }

    /// Search FAQs by keyword
    static func searchFAQs(query: String) -> [FAQItem] {
        let lowercasedQuery = query.lowercased()
        return allFAQs.filter {
            $0.question.lowercased().contains(lowercasedQuery) ||
                $0.answer.lowercased().contains(lowercasedQuery)
        }
    }
}



