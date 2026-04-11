import Foundation

/// American Privacy Policy content (English, US law compliance)
/// For American citizens - complies with CCPA, CPRA, and state privacy laws
enum PrivacyPolicyAmericanContent {

    typealias Section = PrivacyPolicyDataProvider.PrivacySection

    static var sections: [Section] {
        [
            introductionSection,
            dataCategoriesSection,
            legalBasisSection,
            purposeSection,
            dataSourcesSection,
            dataSharingSection,
            retentionSection,
            userRightsSection,
            securitySection,
            cookiesSection,
            breachSection,
            marketingSection,
            profilingSection,
            changesSection,
            contactSection,
            jurisdictionSection
        ]
    }

    // MARK: - Section 1: Introduction

    static let introductionSection = Section(
        id: "introduction",
        title: "1. Introduction & Data Controller",
        content: """
        **Data Controller:**
        \(LegalIdentity.companyLegalName)
        [Registered Address]
        [Registration Number]
        Email: \(CompanyContactInfo.privacyEmail)
        Phone: +1 [number]

        **Privacy Officer:**
        [Name]
        Email: \(CompanyContactInfo.privacyEmail)
        Phone: +1 [number]

        **Policy Version:**
        Version 1.0
        Last Updated: [Date]
        Effective Date: [Date]

        **Scope:**
        This Privacy Policy applies to all American users of the \(LegalIdentity.platformName) App, including investors and traders. It describes how we collect, use, store, and protect your personal information in compliance with applicable U.S. privacy laws, including the California Consumer Privacy Act (CCPA), California Privacy Rights Act (CPRA), and other state privacy laws.
        """,
        icon: "info.circle.fill"
    )

    // MARK: - Section 2: Data Categories

    static let dataCategoriesSection = Section(
        id: "data-categories",
        title: "2. Categories of Personal Information Collected",
        content: """
        We collect the following categories of personal information:

        **A. Identifiers:**
        - Full name (first, last, salutation, academic title)
        - Email address
        - Phone number
        - Username
        - Customer ID / User ID
        - IP address
        - Device identifiers

        **B. Personal Information:**
        - Date of birth
        - Place of birth
        - Country of birth
        - Nationality
        - Postal address (street, city, postal code, state, country)
        - Additional addresses (if applicable)

        **C. Financial Information:**
        - Tax identification number (TIN/SSN)
        - Additional tax residences
        - Tax numbers for multiple jurisdictions
        - Income information (amount, range, sources)
        - Employment status
        - Cash and liquid assets
        - Bank account information (if collected)
        - Payment method information

        **D. Identity Verification Documents:**
        - Passport images (front/back)
        - ID card images (front/back)
        - Driver's license images
        - Address verification documents
        - KYC verification status
        - AML compliance status

        **E. Commercial Information:**
        - Investment amounts
        - Investment history
        - Trading activity
        - Trade orders (buy/sell)
        - Securities holdings
        - Profit/loss records
        - Commission records
        - Transaction history

        **F. Internet or Electronic Network Activity:**
        - App usage patterns
        - Feature usage statistics
        - Device information
        - Browser/App version
        - Operating system
        - Screen resolution
        - Time zone
        - Language preferences
        - Login history

        **G. Geolocation Data:**
        - IP address location
        - Device location (if enabled)

        **H. Professional or Employment Information:**
        - Employment status
        - Income information
        - Employment history (if collected)

        **I. Inferences:**
        - Risk tolerance assessment
        - Investment experience
        - Trading frequency
        - Investment knowledge level
        - Desired return expectations
        - User preferences

        **J. Sensitive Personal Information (if applicable):**
        - Government-issued identification numbers (SSN, TIN)
        - Financial account information
        - Precise geolocation data
        """,
        icon: "list.bullet.rectangle"
    )

    // MARK: - Section 3: Legal Basis

    static let legalBasisSection = Section(
        id: "legal-basis",
        title: "3. Legal Basis for Processing",
        content: """
        We process your personal information based on the following legal bases:

        **A. Performance of Contract:**
        - **Applies to**: Account creation, trading execution, investment management
        - **Information**: Personal identification, contact info, financial data, trading data
        - **Justification**: Necessary to provide app services

        **B. Legal Obligation:**
        - **Applies to**: KYC/AML compliance, tax reporting, regulatory requirements
        - **Information**: Identity documents, tax information, transaction records
        - **Justification**: Required by federal and state laws, SEC regulations, FINRA requirements (if applicable)

        **C. Legitimate Business Interests:**
        - **Applies to**: Analytics, fraud prevention, security, business operations
        - **Information**: Usage data, device information, behavioral data
        - **Justification**: App security, service improvement, fraud prevention
        - **Opt-Out Rights**: You have the right to opt-out of certain processing

        **D. Consent:**
        - **Applies to**: Marketing communications, optional analytics, cookies, sensitive personal information
        - **Information**: Marketing preferences, optional behavioral tracking
        - **Justification**: You have provided explicit consent
        - **Withdrawal**: Can be withdrawn at any time

        **E. Compliance with Legal Obligations:**
        - **Applies to**: Regulatory reporting, tax compliance, AML/KYC requirements
        - **Justification**: Required by applicable federal and state laws
        """,
        icon: "scale.3d"
    )

    // MARK: - Section 4: Purpose

    static let purposeSection = Section(
        id: "purpose",
        title: "4. Purpose of Processing",
        content: """
        We process your information for the following purposes:

        **A. Service Provision:**
        - Account creation and management
        - User authentication and authorization
        - Trading app operation
        - Investment pool management
        - Order execution
        - Profit/loss calculation and distribution
        - Invoice generation
        - Account statement generation

        **B. Legal & Regulatory Compliance:**
        - KYC (Know Your Customer) verification
        - AML (Anti-Money Laundering) compliance
        - Tax reporting and compliance
        - Securities regulations (SEC, FINRA if applicable)
        - Regulatory reporting
        - Record retention requirements

        **C. Security & Fraud Prevention:**
        - Account security
        - Fraud detection and prevention
        - Suspicious activity monitoring
        - Identity verification
        - Transaction monitoring

        **D. Communication:**
        - Customer support
        - Service notifications
        - Important account updates
        - Legal document updates

        **E. Business Operations:**
        - Service improvement
        - Analytics and reporting
        - Performance monitoring
        - Technical troubleshooting
        - System maintenance

        **F. Marketing (With Consent):**
        - Promotional communications
        - Product updates
        - Educational content
        """,
        icon: "target"
    )

    // MARK: - Section 5: Data Sources

    static let dataSourcesSection = Section(
        id: "data-sources",
        title: "5. Sources of Personal Information",
        content: """
        We obtain your personal information from the following sources:

        **A. Directly from You:**
        - Registration forms
        - Profile updates
        - Document uploads
        - Support communications
        - Account activity

        **B. Generated by App:**
        - Transaction records
        - Account statements
        - Invoices
        - Usage analytics
        - System logs

        **C. Third-Party Sources:**
        - **Brokers/Exchanges**: Trading execution data
        - **Identity Verification Services**: KYC verification (if used)
        - **Credit Bureaus**: Credit checks (if performed)
        - **Regulatory Databases**: PEP (Politically Exposed Persons) screening
        - **Market Data Providers**: Securities prices, market data

        **D. Public Sources:**
        - Company registries (for corporate accounts)
        - Regulatory filings
        - Public records
        """,
        icon: "arrow.down.circle.fill"
    )

    // MARK: - Section 6: Data Sharing

    static let dataSharingSection = Section(
        id: "data-sharing",
        title: "6. Disclosure of Personal Information",
        content: """
        We may share your personal information with the following categories of third parties:

        **A. Service Providers:**
        - **Backend Infrastructure**: Parse Server, cloud hosting providers
        - **Database Services**: MongoDB, PostgreSQL, Redis
        - **File Storage**: MinIO/S3, cloud storage providers
        - **Email Services**: Transactional email providers
        - **Push Notifications**: APNS (Apple), FCM (Google)
        - **Analytics Services**: Internal analytics service
        - **Market Data Providers**: Real-time trading data

        **B. Financial Institutions:**
        - **Brokers**: Order execution
        - **Exchanges**: Trade execution
        - **Payment Processors**: If applicable
        - **Banks**: If bank account information shared

        **C. Regulatory & Legal Authorities:**
        - **SEC**: Securities and Exchange Commission (if applicable)
        - **FINRA**: Financial Industry Regulatory Authority (if applicable)
        - **IRS**: Tax reporting
        - **State Regulators**: State securities regulators
        - **Law Enforcement**: If legally required
        - **Courts**: If court order received

        **D. Business Partners:**
        - **Licensed Brokers**: Trading execution partners
        - **Compliance Service Providers**: KYC/AML services

        **E. Corporate Transactions:**
        - **Mergers/Acquisitions**: Data transfer in business transfers
        - **Affiliates**: If applicable

        **F. Sale of Personal Information:**
        We do NOT sell your personal information to third parties.

        **G. Sharing for Business Purposes:**
        We may share personal information with service providers for business purposes. These providers are contractually obligated to protect your information and use it only for specified purposes.
        """,
        icon: "person.2.fill"
    )

    // MARK: - Section 7: Retention

    static let retentionSection = Section(
        id: "retention",
        title: "7. Data Retention Periods",
        content: """
        We retain your personal information for the following periods:

        **A. Account Data:**
        - **Active Accounts**: Retained while account is active
        - **Closed Accounts**:
          - Financial records: 7 years (IRS requirements)
          - KYC documents: 5-7 years (AML requirements)
          - Transaction records: 7 years (SEC/FINRA requirements)
          - Personal information: Until legal retention expires

        **B. Transaction Data:**
        - **Trading Records**: 7 years (SEC/FINRA requirements)
        - **Investment Records**: 7 years
        - **Invoices**: 7 years (tax law)
        - **Account Statements**: 7 years

        **C. KYC/AML Data:**
        - **Identity Documents**: 5-7 years after account closure
        - **Verification Records**: 5-7 years
        - **Compliance Documentation**: Per regulatory requirements

        **D. Marketing Data:**
        - **Consent Records**: Until consent withdrawn + 3 years
        - **Marketing Lists**: Until opt-out

        **E. Analytics Data:**
        - **Usage Analytics**: 2-3 years (anonymized after 1 year)
        - **Performance Metrics**: 3-5 years

        **F. Legal Documents:**
        - **Terms Acceptance**: Permanent (for legal defense)
        - **Privacy Policy Acceptance**: Permanent

        After retention periods expire, data is deleted or anonymized in accordance with applicable law.
        """,
        icon: "clock.fill"
    )

    // MARK: - Section 8: User Rights

    static let userRightsSection = Section(
        id: "user-rights",
        title: "8. Your Privacy Rights",
        content: """
        You have the following rights regarding your personal information:

        **A. Right to Know (CCPA/CPRA):**
        - **What**: Request information about what personal information we collect, use, disclose, and sell
        - **How**: Contact us at \(CompanyContactInfo.privacyEmail) or use the in-app request feature
        - **Timeline**: We will respond within 45 days (may extend to 90 days with notice)
        - **Format**: We will provide the information in a readily usable format

        **B. Right to Delete (CCPA/CPRA):**
        - **What**: Request deletion of your personal information
        - **Limitations**:
          - Legal retention requirements (tax, AML, SEC/FINRA)
          - Ongoing contractual obligations
          - Legal claims
          - Other exceptions under applicable law
        - **How**: Contact us at \(CompanyContactInfo.privacyEmail)
        - **Timeline**: We will respond within 45 days (may extend to 90 days with notice)

        **C. Right to Opt-Out (CCPA/CPRA):**
        - **What**: Opt-out of the sale or sharing of personal information
        - **Note**: We do not sell personal information, but you can opt-out of sharing for business purposes
        - **How**: Settings in the app or contact us
        - **Effect**: Processing stops for opted-out purposes

        **D. Right to Correct (CPRA):**
        - **What**: Correct inaccurate personal information
        - **How**: Update profile or contact support
        - **Timeline**: Without undue delay
        - **Verification**: May require documentation

        **E. Right to Non-Discrimination:**
        - **What**: We will not discriminate against you for exercising your privacy rights
        - **Protection**: You will receive the same quality of service regardless of exercising rights

        **F. Right to Limit Use of Sensitive Personal Information (CPRA):**
        - **What**: Limit the use of sensitive personal information
        - **Scope**: Applies to sensitive personal information as defined by CPRA
        - **How**: Contact us or use app settings

        **G. Right to Data Portability:**
        - **What**: Receive your data in a portable format
        - **Format**: Machine-readable format (JSON, CSV)
        - **Scope**: Personal information you provided to us

        **H. Right to Withdraw Consent:**
        - **What**: Withdraw previously given consent
        - **Effect**: Processing stops (if consent was only legal basis)
        - **How**: Settings, contact support
        - **Ease**: As easy as giving consent

        **Exercising Your Rights:**
        - Email: \(CompanyContactInfo.privacyEmail)
        - In-App: Support feature
        - Written: Postal address provided
        - **Verification**: Identity verification required for security
        - **Timeline**: Response within 45 days (extendable to 90 days with notice)
        - **Fees**: Free of charge (may charge for excessive requests)
        - **Authorized Agents**: You may designate an authorized agent to exercise rights on your behalf
        """,
        icon: "hand.raised.fill"
    )

    // MARK: - Section 9: Security

    static let securitySection = Section(
        id: "security",
        title: "9. Security Measures",
        content: """
        We implement the following security measures to protect your personal information:

        **A. Technical Measures:**
        - **Encryption**:
          - AES-256 for data at rest
          - TLS 1.3 for data in transit
          - Keychain integration for sensitive data (iOS)
        - **Authentication**:
          - Strong password requirements
          - Biometric authentication (Face ID, Touch ID)
          - Multi-factor authentication (if available)
          - Session management
        - **Access Controls**:
          - Role-based access control
          - Least privilege principle
          - Regular access reviews
        - **Network Security**:
          - Firewalls
          - Intrusion detection
          - DDoS protection
        - **Data Backup**:
          - Regular backups
          - Encrypted backups
          - Disaster recovery plans

        **B. Organizational Measures:**
        - **Employee Training**: Data protection and security training
        - **Access Logging**: Audit trails
        - **Incident Response**: Data breach procedures
        - **Regular Audits**: Security assessments
        - **Vendor Management**: Data processing agreements

        **C. Physical Security:**
        - **Data Centers**: Physical security measures
        - **Office Security**: Access controls

        **Important**: No system is 100% secure. We strive for the highest security standards but cannot guarantee absolute security. We will notify you of any data breaches as required by law.
        """,
        icon: "lock.shield.fill"
    )

    // MARK: - Section 10: Cookies

    static let cookiesSection = Section(
        id: "cookies",
        title: "10. Cookies & Tracking Technologies",
        content: """
        **A. Essential Cookies:**
        - **Purpose**: App functionality
        - **Legal Basis**: Necessary for service provision
        - **Examples**: Session cookies, authentication tokens
        - **Opt-Out**: Not possible (required for service)

        **B. Analytics Cookies:**
        - **Purpose**: Service improvement, usage analytics
        - **Legal Basis**: Consent or legitimate business interests
        - **Examples**: Internal analytics service
        - **Opt-Out**: Settings or contact support
        - **Third Parties**: If any analytics providers used

        **C. Marketing Cookies:**
        - **Purpose**: Advertising, retargeting
        - **Legal Basis**: Consent
        - **Opt-Out**: Always possible
        - **Third Parties**: If any marketing providers used

        **D. Mobile App Tracking:**
        - **Device Identifiers**: IDFA (iOS), GAID (Android)
        - **Purpose**: Analytics, personalization
        - **Legal Basis**: Consent
        - **Opt-Out**: Device settings or app settings

        **E. Do Not Track:**
        - We respect "Do Not Track" signals from your browser
        - However, some features may require tracking for functionality

        You can manage your cookie and tracking preferences in the app settings.
        """,
        icon: "eye.slash.fill"
    )

    // MARK: - Section 11: Breach

    static let breachSection = Section(
        id: "breach",
        title: "11. Data Breach Notification",
        content: """
        **A. User Notification:**
        - **Timeline**: Without unreasonable delay, as required by applicable state and federal laws
        - **Content**:
          - Nature of breach
          - Categories of information affected
          - Likely consequences
          - Measures taken
          - Recommendations for users
        - **Method**: Email, in-app notification, or both
        - **Legal Requirements**: We comply with all applicable state breach notification laws

        **B. Regulatory Notification:**
        - **Timeline**: As required by applicable laws
        - **Authorities**: State attorneys general, federal regulators (if applicable)
        - **Content**: Detailed breach information as required by law

        **C. Documentation:**
        - **Breach Register**: Maintained per legal requirements
        - **Records**: All breaches documented

        If you notice a suspected data breach, please contact us immediately at \(CompanyContactInfo.privacyEmail).
        """,
        icon: "exclamationmark.triangle.fill"
    )

    // MARK: - Section 12: Marketing

    static let marketingSection = Section(
        id: "marketing",
        title: "12. Marketing & Communications",
        content: """
        **A. Marketing Communications:**
        - **Types**: Email, push notifications, in-app messages
        - **Content**: Promotional, educational, updates
        - **Frequency**: As specified in preferences

        **B. Consent Management:**
        - **Opt-In**: Explicit consent required for marketing
        - **Opt-Out**: Easy withdrawal mechanism (unsubscribe links, app settings)
        - **Preferences**: Granular control (email, push, SMS)
        - **Record Keeping**: Consent version, date tracked

        **C. Third-Party Marketing:**
        - **Sharing**: We do not share personal information with third parties for their marketing purposes without consent
        - **Opt-Out**: How to prevent sharing

        **D. Text Messages (SMS):**
        - If we send text messages, you can opt-out by replying STOP
        - Standard message and data rates may apply

        You can change your marketing preferences at any time in the app settings or by contacting us.
        """,
        icon: "megaphone.fill"
    )

    // MARK: - Section 13: Profiling

    static let profilingSection = Section(
        id: "profiling",
        title: "13. Profiling & Automated Decision-Making",
        content: """
        **A. Profiling Activities:**
        - **Risk Assessment**: Automated risk tolerance calculation
        - **Trader Matching**: Algorithm-based trader selection
        - **Investment Recommendations**: If any automated recommendations
        - **Purpose**: Service personalization, risk management

        **B. Automated Decisions:**
        - **Trading Decisions**: If automated trading enabled
        - **Risk Classification**: Automated risk assessment
        - **Account Approval**: Automated KYC verification (if applicable)

        **C. Your Rights:**
        - **Human Review**: Right to request human review of automated decisions
        - **Explanation**: Right to explanation of logic
        - **Opt-Out**: Right to opt-out of certain automated processing

        You have the right to request human review of automated decisions that significantly affect you.
        """,
        icon: "brain.head.profile"
    )

    // MARK: - Section 14: Changes

    static let changesSection = Section(
        id: "changes",
        title: "14. Changes to Privacy Policy",
        content: """
        **A. Notification of Changes:**
        - **Material Changes**: We will notify you of material changes
        - **Methods**: Email, in-app notification, website notice
        - **Version Control**: Version numbers, dates tracked

        **B. Acceptance:**
        - **Continued Use**: Continued use after changes constitutes acceptance
        - **Objection**: Can terminate account if disagree
        - **History**: Previous versions available

        **C. Significant Changes:**
        - **Examples**: New data categories, new purposes, new third parties, changes to rights
        - **Consent**: May require new consent for material changes

        We will inform you of any material changes to this Privacy Policy. Your continued use of the App after changes take effect constitutes acceptance of the updated policy.
        """,
        icon: "arrow.triangle.2.circlepath"
    )

    // MARK: - Section 15: Contact

    static let contactSection = Section(
        id: "contact",
        title: "15. Contact Information & Exercising Rights",
        content: """
        **A. Privacy Inquiries:**
        - **Email**: \(CompanyContactInfo.privacyEmail)
        - **Support**: In-app support feature
        - **Phone**: +1 [number]
        - **Address**: [Address]

        **B. Exercising Rights:**
        - **How**: Email, in-app request, written request
        - **Verification**: Identity verification required for security
        - **Timeline**: Response within 45 days (extendable to 90 days with notice)
        - **Fees**: Free of charge (may charge for excessive requests)
        - **Authorized Agents**: You may designate an authorized agent

        **C. Complaints:**
        - **Internal**: Contact us first at \(CompanyContactInfo.privacyEmail)
        - **External**:
          - **California**: California Attorney General
          - **Other States**: State attorney general (if applicable)
          - **Federal**: FTC, CFPB (if applicable)

        **D. California-Specific:**
        - **California Privacy Rights**: Additional rights under CCPA/CPRA
        - **Shine the Light Law**: California residents can request information about sharing with third parties for marketing

        **Supervisory Authorities:**
        - **California**: California Attorney General's Office
        - **Federal**: Federal Trade Commission (FTC)
        """,
        icon: "envelope.fill"
    )

    // MARK: - Section 16: Jurisdiction

    static let jurisdictionSection = Section(
        id: "jurisdiction",
        title: "16. Applicable Law & Jurisdiction",
        content: """
        **A. Primary Applicable Laws:**
        - **Federal**:
          - Gramm-Leach-Bliley Act (GLBA) - if providing financial services
          - SEC Regulations - if operating as broker-dealer or investment adviser
          - FINRA Requirements - if applicable
        - **State Privacy Laws**:
          - **California**: CCPA, CPRA
          - **Virginia**: VCDPA
          - **Colorado**: CPA
          - **Connecticut**: CTDPA
          - **Other States**: As applicable

        **B. Your Rights by State:**
        - **California**: Full CCPA/CPRA rights (know, delete, opt-out, correct, non-discrimination)
        - **Virginia**: VCDPA rights (access, delete, opt-out, correct)
        - **Colorado**: CPA rights (access, delete, opt-out, correct)
        - **Connecticut**: CTDPA rights (access, delete, opt-out, correct)
        - **Other States**: Rights as provided by applicable state laws

        **C. Governing Law:**
        - This Privacy Policy is governed by applicable U.S. federal and state laws
        - Disputes shall be resolved in accordance with applicable law
        - Jurisdiction: As specified in Terms of Service

        **D. International Users:**
        - If you are located outside the United States, different privacy laws may apply
        - Please refer to the appropriate jurisdiction-specific privacy policy

        This Privacy Policy is specifically designed for American users and complies with applicable U.S. privacy laws.
        """,
        icon: "globe.americas.fill"
    )
}





