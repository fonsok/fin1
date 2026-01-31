import Foundation

/// Centralized provider for landing page FAQ content
/// Focused on questions from interested parties (prospects) before sign-up
struct LandingFAQProvider {
    // MARK: - Landing Page FAQs

    /// Curated FAQs for interested parties visiting the landing page
    /// NOTE: Must be `var` (computed) so AppBrand.appName is evaluated at access time, not static init.
    static var landingFAQs: [FAQItem] { [
        // MARK: - Platform Basics
        FAQItem(
            id: "landing-1",
            question: "What is \(AppBrand.appName)?",
            answer: "\(AppBrand.appName) is an investment pool platform that connects investors with experienced traders. Investors can invest in traders' strategies, and profits/losses are shared proportionally among all participants in each investment pool.\nTraders receive a commision from Investors´ profits.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-2",
            question: "How does the investment pool system work?",
            answer: "When you invest, your funds join a pool. The selected trader executes a trade and automatically also a trade, using the pooled capital, is executed.\nProfits and losses are distributed proportionally based on each investor's share of the pool.\nThe trader receives a certain percentage commission from investors´ profits.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-3",
            question: "What makes \(AppBrand.appName) different from traditional investment platforms?",
            answer: "\(AppBrand.appName) focuses on direct access to experienced traders and transparent, proportional profit-sharing. You can choose specific traders based on their performance and risk profile, rather than investing in generic funds.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-3b",
            question: "What makes \(AppBrand.appName) different from traditional asset management?",
            answer: "\(AppBrand.appName) offers several key advantages over traditional asset management:\n• Direct access to individual traders rather than anonymous fund managers\n• Transparent performance metrics and trade history.\n• Lower minimum investment requirements.\n• Real-time updates and notifications.\n• Proportional profit sharing with clear fee structures.\n• Ability to choose specific traders based on their strategies and performance.\n• Technology-driven platform that provides instant access to information and transactions.\n\nUnlike traditional asset management, you have full control over which traders you invest with and can see exactly how your money is being managed.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-usp",
            question: "What is the unique advantage (USP) of \(AppBrand.appName)?",
            answer: "The unique advantage (USP) of this app is: Bare figures led investing for everyone – wealth maximization with real-time strategies and personalized investments.\n\nThis USP sets the app apart from classic investment and trading platforms by making day trading expertise accessible to a broader target group without them having to intensively engage with technics and markets.",
            category: .platformOverview
        ),

        // MARK: - Who Should Use the Platform
        FAQItem(
            id: "landing-4",
            question: "Is \(AppBrand.appName) suitable for beginners?",
            answer: "\(AppBrand.appName) is designed for investors comfortable with high-risk, high-gain strategies. We recommend understanding investment risks and completing our risk assessment during registration.\n Note: please do not invest more than 2% of your assets.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-5",
            question: "Do I need trading experience to use \(AppBrand.appName)?",
            answer: "No. As an investor, you don't need trading experience—you select traders to invest with. Traders need experience and must meet platform requirements.",
            category: .platformOverview
        ),

        // MARK: - How It Works
        FAQItem(
            id: "landing-6",
            question: "How do I get started?",
            answer: "Create an account, complete the step-by-step registration (including KYC), choose your role (Investor or Trader), and start exploring. Investors can browse traders and make investments; traders can set up their trading environment.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-7",
            question: "How do I choose which trader to invest with?",
            answer: "Use the Investor Discovery section to browse traders, view performance metrics (returns, win rate), specialization, risk level, and minimum investment requirements. You can add traders to your watchlist for later review.",
            category: .investments
        ),
        FAQItem(
            id: "landing-8",
            question: "How are profits calculated and distributed?",
            answer: "When a trader completes a trade (both buy and sell executed), profits are calculated after fees. Each investor receives a proportional share based on their investment amount relative to the total pool size.",
            category: .investments
        ),

        // MARK: - Risk & Safety
        FAQItem(
            id: "landing-9",
            question: "Is my investment guaranteed?",
            answer: "No. \(AppBrand.appName) does not guarantee returns. All investments carry risk, and you can lose your invested capital. Only invest what you can afford to lose.\n Note: please do not invest more than 2% of your assets.",
            category: .investments
        ),
        FAQItem(
            id: "landing-10",
            question: "Can I lose more than I invest?",
            answer: "Your maximum loss is limited to your invested amount. You cannot lose more than you've invested in a pool.",
            category: .investments
        ),

        // MARK: - Costs & Fees
        FAQItem(
            id: "landing-11",
            question: "Are there fees to use \(AppBrand.appName)?",
            answer: "Trading fees apply per trade (order fees, exchange fees, foreign transaction costs if applicable). All fees are disclosed before you confirm any transaction. Check the current fee schedule in your account settings.",
            category: .investments
        ),

        // MARK: - Trader Information
        FAQItem(
            id: "landing-16",
            question: "How do traders make money?",
            answer: "Traders receive a commission from investors' profits. When a trade generates profit, the trader earns a percentage of that profit as compensation. This commission structure aligns the trader's interests with investor success—traders only earn when investors profit.",
            category: .investments
        ),
        FAQItem(
            id: "landing-17",
            question: "What qualifications do traders need?",
            answer: "Traders on \(AppBrand.appName) must have significant trading experience and meet platform requirements. They must demonstrate expertise in trading strategies, risk management, and market analysis by reaching best performances/figures. All traders are verified and must invest their own capital alongside investor funds, ensuring they have a personal stake in their trading decisions.",
            category: .investments
        ),
        FAQItem(
            id: "landing-18",
            question: "How do traders manage investments?",
            answer: "Traders execute trades using own capital. When a trader places a trade, the system automatically combines the trader's own capital with the investment pool capital. All trades are transparent—investors can see trade history, performance metrics, and real-time updates. Traders manage the trading strategy while investors maintain visibility into how their funds are being used.",
            category: .investments
        ),
        FAQItem(
            id: "landing-19",
            question: "Can I see a trader's performance history before investing?",
            answer: "Yes. The Investor Discovery section provides comprehensive trader profiles including performance metrics (returns, win rate), trading history, specialization areas, risk level, and minimum investment requirements. You can review detailed statistics and past performance to make informed investment decisions before committing your capital.",
            category: .investments
        ),

        // MARK: - Security
        FAQItem(
            id: "landing-12",
            question: "How secure is my financial information?",
            answer: "\(AppBrand.appName) uses industry-standard security: AES-256 encryption, secure storage (Keychain), TLS 1.3 for network communication, and biometric authentication (Face ID/Touch ID) support.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-13",
            question: "Is my personal data protected?",
            answer: "Yes. \(AppBrand.appName) complies with GDPR. Your data is used only for platform operations and legal compliance. We do not share your data with third parties without consent. See our Privacy Policy for details.",
            category: .platformOverview
        ),

        // MARK: - Regulatory
        FAQItem(
            id: "landing-14",
            question: "Is \(AppBrand.appName) regulated?",
            answer: "\(AppBrand.appName) complies with applicable financial services regulations, GDPR, KYC/AML requirements, and tax reporting obligations. We act as a technology platform connecting traders and investors.",
            category: .platformOverview
        ),
        FAQItem(
            id: "landing-15",
            question: "Does \(AppBrand.appName) provide investment advice?",
            answer: "No. \(AppBrand.appName) is a technology platform that facilitates trading and investment management. We do not provide investment advice, recommendations, or financial advisory services. All investment decisions are made independently by users.",
            category: .platformOverview
        ),

        // MARK: - Getting Started
        FAQItem(
            id: "gs-1",
            question: "How do I create an account?",
            answer: "To create an account, tap 'Sign Up' on the landing page. You'll go through a registration process that includes providing your personal information, verifying your identity (KYC), and setting up your account preferences. Make sure you have a valid email address and identification documents ready.",
            category: .gettingStarted
        ),
        FAQItem(
            id: "gs-2",
            question: "What is the difference between Investor and Trader roles?",
            answer: "Investors can discover and invest in high experienced traders, track their portfolio performance, and receive proportional returns. Traders execute trades, and share profits/losses proportionally with their investors. You can choose your role during registration.",
            category: .gettingStarted
        ),
        FAQItem(
            id: "gs-3",
            question: "How do I verify my identity (KYC)?",
            answer: "During registration, you'll be asked to upload identification documents (passport or ID card). You'll also need to provide proof of address. Our team will review your documents, and you'll receive a notification once verification is complete. This process typically takes 1-3 business days.",
            category: .gettingStarted
        ),
        FAQItem(
            id: "gs-4",
            question: "Can I change my role after registration?",
            answer: "Currently, your role is set during registration and cannot be changed.",
            category: .gettingStarted
        )
    ] }

    // MARK: - Computed Properties

    /// FAQs grouped by category
    static var landingFAQsByCategory: [FAQCategory: [FAQItem]] {
        Dictionary(grouping: landingFAQs) { $0.category }
    }

    /// Categories sorted with Platform Overview first, then Getting Started, then Investments
    static var sortedCategories: [FAQCategory] {
        let categories = landingFAQsByCategory.keys.filter { category in
            guard let faqs = landingFAQsByCategory[category] else { return false }
            return !faqs.isEmpty
        }

        return categories.sorted { category1, category2 in
            // Platform Overview first
            if category1 == .platformOverview && category2 != .platformOverview {
                return true
            }
            if category2 == .platformOverview && category1 != .platformOverview {
                return false
            }
            // Getting Started second
            if category1 == .gettingStarted && category2 != .gettingStarted && category2 != .platformOverview {
                return true
            }
            if category2 == .gettingStarted && category1 != .gettingStarted && category1 != .platformOverview {
                return false
            }
            // Investments third
            if category1 == .investments && category2 != .investments && category2 != .platformOverview && category2 != .gettingStarted {
                return true
            }
            if category2 == .investments && category1 != .investments && category1 != .platformOverview && category1 != .gettingStarted {
                return false
            }
            // All other categories alphabetically
            return category1.rawValue < category2.rawValue
        }
    }
}

