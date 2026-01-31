import Foundation

/// English content for Terms of Service
enum TermsOfServiceEnglishContent {

    typealias Section = TermsOfServiceDataProvider.TermsSection

    static func sections(commissionRate: Double) -> [Section] {
        [
            introSection,
            acceptanceSection,
            regulatorySection,
            platformSection,
            accountSection,
            tradingSection,
            investmentSection(commissionRate: commissionRate),
            taxSection,
            risksSection,
            responsibilitiesSection,
            limitationsSection,
            ipSection,
            privacySection,
            terminationSection,
            disputesSection,
            changesSection,
            contactSection,
            specialSection,
            severabilitySection
        ]
    }

    // MARK: - Sections 1-5

    static let introSection = Section(
        id: "introduction",
        title: "1. Introduction & Definitions",
        content: """
        \(LegalIdentity.platformName) is a technology platform that facilitates securities trading and investment management services. The platform connects traders and investors, enabling investment opportunities in securities trading activities.

        **Definitions:**
        - **Platform** or **Service**: The \(LegalIdentity.platformName) application and related services
        - **User**: Any individual or entity using the Platform
        - **Trader**: Users who execute securities trades on the Platform
        - **Investor**: Users who invest capital with traders through the Platform
        - **Investment**: Capital allocated by investors to traders for trading activities
        - **Securities**: Financial instruments traded on the Platform
        """,
        icon: "info.circle.fill"
    )

    static let acceptanceSection = Section(
        id: "acceptance",
        title: "2. Acceptance of Terms",
        content: """
        By accessing or using the \(LegalIdentity.platformName) Platform, you agree to be bound by these Terms of Service. If you do not agree to these Terms, you must not use the Platform.

        **Modifications:**
        We reserve the right to modify these Terms at any time. Material changes will be communicated with at least 30 days' notice. Continued use of the Platform after changes constitutes acceptance of the modified Terms.

        **Eligibility:**
        You must be at least 18 years old and have legal capacity to enter into binding agreements. You must comply with all applicable laws and regulations in your jurisdiction.
        """,
        icon: "checkmark.circle.fill"
    )

    static let regulatorySection = Section(
        id: "regulatory",
        title: "3. Regulatory Compliance",
        content: """
        **German Securities Trading Regulations:**
        The Platform operates in compliance with:
        - **Wertpapierhandelsgesetz (WpHG)** - German Securities Trading Act
        - **Wertpapierhandelsverordnung (WpDVerOV)** - German Securities Trading Ordinance
        - All transactions are executed in accordance with these regulations

        **Tax Law Compliance:**
        - All tax calculations are performed in accordance with **§ 20 EStG** (German Income Tax Act)
        - Capital gains are subject to **Abgeltungsteuer** (25% + Soli) on realized gains
        - Tax withholding is handled by the executing bank, not by the Platform
        - Users are solely responsible for their tax compliance

        **GDPR/DSGVO Compliance:**
        The Platform complies with the General Data Protection Regulation (GDPR) and German Data Protection Act (DSGVO). Please refer to our Privacy Policy for detailed information about data processing.
        """,
        icon: "shield.checkered"
    )

    static let platformSection = Section(
        id: "platform",
        title: "4. Platform Description & Service Scope",
        content: """
        **Nature of Service:**
        \(LegalIdentity.platformName) is a **technology platform** that facilitates securities trading and investment management. The Platform provides technology infrastructure, connects traders and investors, executes trades through licensed brokers, and provides transaction records.

        **What We Do NOT Provide:**
        - Investment advice or recommendations
        - Guaranteed investment returns or performance
        - Financial advisory services
        - Guaranteed trader availability or investment opportunities
        - Tax advice (users must consult tax advisors)

        **Service Limitations:**
        - The Platform acts as an intermediary, not as principal
        - Users make independent investment decisions
        - The Platform does not guarantee execution at displayed prices
        - Service availability is not guaranteed to be uninterrupted
        """,
        icon: "app.badge"
    )

    static let accountSection = Section(
        id: "account",
        title: "5. User Eligibility & Account Requirements",
        content: """
        **Account Eligibility:**
        To use the Platform, you must be at least 18 years old, have legal capacity, provide accurate information, complete identity verification (KYC), and comply with all applicable laws.

        **Account Types:**
        - **Trader Accounts**: For users who execute securities trades
        - **Investor Accounts**: For users who invest capital with traders

        **Account Balance:**
        - Initial Balance: New accounts may receive an initial balance of €50,000 (demo/simulation purposes)
        - Minimum Cash Reserve: Accounts must maintain a minimum cash reserve of €12
        - Balance Purpose: Account balances are for Platform use only
        """,
        icon: "person.circle.fill"
    )

    // MARK: - Sections 6-10

    static let tradingSection = Section(
        id: "trading",
        title: "6. Trading Terms & Conditions",
        content: """
        **Order Execution:**
        - Orders are executed through licensed brokers and exchanges
        - Execution prices are subject to market conditions
        - The Platform does not guarantee execution at displayed prices

        **Order Fees & Charges:**
        - **Order Fee**: 0.5% of order amount (minimum €5, maximum €50)
        - **Exchange Fee**: 0.1% of order amount (minimum €1, maximum €20)
        - **Foreign Costs**: €1.50 per transaction
        - Fees are calculated on the total securities value and are non-refundable once executed

        **Trading Limits:**
        Orders must meet minimum thresholds and sufficient balance must be available (including fees and minimum reserve).
        """,
        icon: "chart.line.uptrend.xyaxis"
    )

    static func investmentSection(commissionRate: Double) -> Section {
        let commissionPercentage = Int(commissionRate * 100)
        return Section(
            id: "investment",
            title: "7. Investment Terms (Investor-Specific)",
            content: """
            **Investment Creation:**
            - Investors can create investments with available traders
            - Minimum investment amount varies by trader
            - Up to 10 investments per user (subject to Platform limits)
            - The Platform does not guarantee investment allocation or trader availability

            **Platform Service Charge:**
            - **Rate**: 1.5% of investment amount (gross amount, includes 19% VAT)
            - **Timing**: Charged at investment creation
            - **Non-Refundable**: Service charges are not refundable
            - **VAT**: The 1.5% includes 19% VAT (German Umsatzsteuer)

            **Investment Returns:**
            - Returns depend on trader performance and market conditions
            - **No Guaranteed Returns**: The Platform does not guarantee any returns
            - **Risk of Loss**: Capital loss is possible
            - **Commission Deductions**: Trader commissions (\(commissionPercentage)%, configurable) are deducted from returns
            """,
            icon: "eurosign.circle.fill"
        )
    }

    static let taxSection = Section(
        id: "tax",
        title: "8. Tax Obligations & Responsibilities",
        content: """
        **User Tax Responsibility:**
        Users are solely responsible for their tax compliance. The Platform provides transaction records and invoices, calculates tax estimates for informational purposes only, and does not provide tax advice.

        **Tax Withholding:**
        - Tax withholding on realized gains is handled by the executing bank
        - **Abgeltungsteuer**: 25% + Soli applies to realized capital gains
        - The Platform does not withhold taxes

        **Tax Documentation:**
        - Invoices are provided for all transactions
        - Monthly account statements are available
        - Users must retain records for tax purposes (minimum 10 years in Germany)
        - Users should consult qualified tax advisors

        **Tax Notes:**
        - Buy Orders: No taxes deducted at purchase. Taxation occurs upon sale per § 20 EStG
        - Sell Orders: Taxation occurs at sale per Abgeltungsteuer (25% + Soli). Bank handles withholding
        - Service Charges: Subject to 19% VAT (Umsatzsteuer)
        """,
        icon: "doc.text.fill"
    )

    static let risksSection = Section(
        id: "risks",
        title: "9. Risk Disclosures",
        content: """
        **IMPORTANT: Investing in securities involves substantial risk of loss.**

        **Investment Risks:**
        - **Capital Loss Risk**: You may lose some or all of your invested capital
        - **Market Volatility**: Securities prices fluctuate based on market conditions
        - **No Guarantee of Returns**: Past performance does not guarantee future results
        - **Trader Performance Risk**: Returns depend on trader performance, which varies
        - **Liquidity Risk**: Investments may not be immediately liquid

        **Platform Risks:**
        - Technical failures, service interruptions, data accuracy limitations
        - Cybersecurity risks despite security measures

        **Acknowledgment:**
        By using the Platform, you acknowledge that you understand the risks involved, are capable of bearing the financial risks, and are making independent investment decisions.
        """,
        icon: "exclamationmark.triangle.fill"
    )

    static let responsibilitiesSection = Section(
        id: "responsibilities",
        title: "10. User Responsibilities & Prohibited Activities",
        content: """
        **User Obligations:**
        Users must provide accurate information, maintain secure credentials, comply with laws, report suspicious activities, and cooperate with Platform investigations.

        **Prohibited Activities:**
        Users are prohibited from:
        - Fraudulent activities, market manipulation, unauthorized access
        - Circumventing Platform controls, providing false information
        - Money laundering, terrorist financing, violating laws
        - Interfering with Platform operations or other users

        **Consequences:**
        Violations may result in account suspension or termination, legal action, reporting to regulatory authorities, forfeiture of funds, or other remedies available under law.
        """,
        icon: "hand.raised.fill"
    )

    // MARK: - Sections 11-15

    static let limitationsSection = Section(
        id: "limitations",
        title: "11. Platform Limitations & Disclaimers",
        content: """
        **Service Availability:**
        - The Platform does not guarantee uninterrupted or error-free service
        - Scheduled and unscheduled maintenance may occur
        - Service may be interrupted due to circumstances beyond our control

        **Data Accuracy:**
        - Market data, prices, and calculations are provided "as is"
        - We do not guarantee accuracy, completeness, or timeliness
        - Users should verify critical information independently

        **Liability Limitations:**
        To the maximum extent permitted by law:
        - Platform liability is limited to direct damages
        - We are not liable for indirect, consequential, incidental, or punitive damages
        - Total liability is limited to fees paid in the 12 months preceding the claim
        - We are not liable for losses due to market conditions or user decisions
        """,
        icon: "info.circle"
    )

    static let ipSection = Section(
        id: "ip",
        title: "12. Intellectual Property",
        content: """
        **Platform Intellectual Property:**
        - All Platform content, software, designs, and materials are proprietary
        - Users are granted a limited, non-exclusive, non-transferable license to use the Platform
        - Users may not copy, modify, distribute, or create derivative works
        - All rights reserved

        **User Data:**
        - Users retain ownership of their data
        - Users grant the Platform a license to process data for service provision
        - Data processing is governed by our Privacy Policy and GDPR/DSGVO

        **Trademarks:**
        - \(LegalIdentity.platformName) and related trademarks are the property of the Platform
        - Users may not use trademarks without written permission
        """,
        icon: "lock.shield.fill"
    )

    static let privacySection = Section(
        id: "privacy",
        title: "13. Data Protection & Privacy",
        content: """
        **GDPR/DSGVO Compliance:**
        The Platform complies with GDPR and DSGVO. Please refer to our Privacy Policy for:
        - Data processing legal basis
        - User rights (access, rectification, erasure, portability)
        - Data retention periods
        - International data transfers (if applicable)
        - Contact information for data protection inquiries

        **Data Security:**
        - We implement industry-standard security measures (AES-256 encryption, TLS 1.3)
        - Data is stored securely (Keychain for sensitive data)
        - However, no system is 100% secure
        - Users must maintain secure credentials

        **Data Sharing:**
        - Data may be shared with brokers, exchanges, and service providers as necessary
        - Data may be shared for regulatory compliance (KYC/AML)
        - Data sharing is governed by our Privacy Policy
        """,
        icon: "hand.raised.slash.fill"
    )

    static let terminationSection = Section(
        id: "termination",
        title: "14. Account Termination & Suspension",
        content: """
        **Termination by User:**
        Users may terminate accounts at any time by contacting Platform support, following account closure procedures, and settling all outstanding obligations.

        **Termination by Platform:**
        The Platform may terminate accounts for violation of Terms, suspicious activity, regulatory requirements, non-compliance with KYC/AML, or other reasons.

        **Account Suspension:**
        Accounts may be suspended pending investigation, for security reasons, regulatory compliance, or non-payment of fees.

        **Post-Termination:**
        Outstanding obligations must be settled, data retention policies apply, and access to Platform services ceases.
        """,
        icon: "xmark.circle.fill"
    )

    static let disputesSection = Section(
        id: "disputes",
        title: "15. Dispute Resolution & Governing Law",
        content: """
        **Governing Law:**
        These Terms are governed by German law.

        **Jurisdiction:**
        Disputes shall be subject to the exclusive jurisdiction of German courts.

        **Dispute Resolution Process:**
        1. Informal Resolution: Contact Platform support first
        2. Mediation: Parties may agree to mediation
        3. Arbitration: If applicable, disputes may be resolved through arbitration
        4. Court Proceedings: If other methods fail, disputes may proceed to court

        **Regulatory Complaints:**
        Users may file complaints with BaFin (Federal Financial Supervisory Authority) or other regulatory authorities as appropriate.
        """,
        icon: "scale.3d"
    )

    // MARK: - Sections 16-19

    static let changesSection = Section(
        id: "changes",
        title: "16. Changes to Terms",
        content: """
        **Modification Rights:**
        The Platform reserves the right to modify these Terms at any time.

        **Notice Requirements:**
        - Material changes: At least 30 days' notice
        - Notification methods: Email, in-app notification, or Platform notice
        - Effective date: Changes become effective on the specified date

        **Acceptance:**
        - Continued use of the Platform after changes constitutes acceptance
        - Users may terminate accounts if they do not agree to changes
        - Terms are versioned and dated, with previous versions archived
        """,
        icon: "arrow.triangle.2.circlepath"
    )

    static let contactSection = Section(
        id: "contact",
        title: "17. Contact Information & Support",
        content: """
        **Support Channels:**
        - Help Center: Available in-app with FAQs and support articles
        - Contact Support: In-app support messaging
        - Response Times: We aim to respond within reasonable timeframes

        **Legal Notices:**
        Company information, registration details, regulatory authorizations, and registered address are available upon request.

        **Data Protection Officer:**
        Contact information for data protection inquiries is available through the Privacy Policy.
        """,
        icon: "envelope.fill"
    )

    static let specialSection = Section(
        id: "special",
        title: "18. Special Provisions",
        content: """
        **Demo/Simulation Accounts:**
        - Initial Balance: €50,000 may be provided for demo/simulation purposes
        - Clarification: Users must understand whether balances are virtual or real
        - Conversion: Demo accounts may be convertible to real accounts (if applicable)
        - Limitations: Demo accounts may have limitations compared to real accounts

        **Money Laundering Prevention:**
        - KYC Requirements: Identity verification is required
        - AML Compliance: Anti-money laundering procedures apply
        - Transaction Monitoring: Transactions are monitored for suspicious activity
        - Reporting: Suspicious activities are reported to authorities
        - User Cooperation: Users must cooperate with KYC/AML procedures

        **Regulatory Reporting:**
        - The Platform may be required to report to regulatory authorities
        - User information may be shared for regulatory compliance
        - Users must provide accurate information for regulatory purposes
        """,
        icon: "exclamationmark.shield.fill"
    )

    static let severabilitySection = Section(
        id: "severability",
        title: "19. Severability & Miscellaneous",
        content: """
        **Severability:**
        If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions shall remain in full force and effect.

        **Entire Agreement:**
        These Terms, together with the Privacy Policy, constitute the entire agreement between users and the Platform.

        **Waiver:**
        Failure to enforce any provision does not constitute a waiver of that provision.

        **Assignment:**
        Users may not assign these Terms without Platform consent. The Platform may assign these Terms.

        **Language:**
        These Terms are provided in German and English. In case of conflict, the German version shall prevail.
        """,
        icon: "doc.text.magnifyingglass"
    )
}




