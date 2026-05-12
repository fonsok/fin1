# FIN1 Support - Frequently Asked Questions

## How can we help you?

---

## General Account and Authentication

### How do I create an account on FIN1?

To create an account, tap "Sign Up" on the landing page and complete the 7-step registration process. You'll need to provide:
- Personal information (name, date of birth, address)
- Contact details (email, phone number)
- Identification documents (passport or ID card)
- Financial information (employment status, income range)
- Risk tolerance assessment
- KYC compliance declarations

### How do I log in to my account?

You can log in using:
- **Email and password**: Enter your registered email and password on the login screen
- **Biometric authentication**: Use Face ID or Touch ID if enabled on your device
- **Direct sign-in**: Quick access option available for registered users

### I forgot my password. How can I reset it?

Use the "Forgot Password" option on the login screen. You'll receive password reset instructions via email.

### Can I use biometric authentication (Face ID/Touch ID)?

Yes, FIN1 supports biometric authentication for secure and convenient access. You can enable this feature in your profile settings after initial login.

### How do I change my account information?

Navigate to your Profile view and select "Edit Profile" to update your personal information, contact details, or address. Some changes may require verification.

### Can I have both Investor and Trader roles?

During registration, you select your primary role (Investor or Trader). If you need to switch roles or have both capabilities, please contact customer support.

### How do I update my risk tolerance?

Your risk tolerance is assessed during registration (scale of 1-10). To update it, go to Profile → Settings → Risk Profile and complete the assessment again.

### What happens if I don't complete the registration process?

Your account will not be activated until all 7 registration steps are completed and verified. You can resume registration at any time by logging in with your email.

### I have another question about account and authentication.

Please contact our customer support team for assistance with any account-related questions not covered here.

---

## Investments and Portfolio (Investor)

### How do I discover traders to invest in?

Use the **Investor Discovery** view to browse available traders. You can filter by:
- Performance metrics (returns, win rate)
- Specialization
- Risk level
- Minimum investment amount

### How do I create an investment?

1. Navigate to **Investor Discovery** or tap on a trader from your dashboard
2. Select "Invest" on the trader's profile
3. Enter your investment amount
4. Choose your investment strategy:
   - **Single Pool**: All funds go to one investment pool
   - **Multiple Pools**: Distribute funds across multiple pools (1-10 pools)
5. Review the investment summary
6. Confirm your investment

### What is the difference between Single Pool and Multiple Pools investment strategies?

- **Single Pool**: Your entire investment amount goes into one investment pool, which participates in trades sequentially
- **Multiple Pools**: Your investment is distributed across multiple pools (1-10), allowing participation in multiple trades simultaneously

### How is my investment allocated across pools?

When selecting Multiple Pools, your investment amount is divided equally across the selected number of pools. Each pool participates in trades independently.

### What is the minimum investment amount?

Minimum investment amounts vary by trader and are displayed on each trader's profile. Check the trader details before investing.

### How do I track my portfolio performance?

Navigate to **Investor Portfolio** to view:
- Total portfolio value
- Active investments
- Performance metrics (P&L, returns)
- Investment history
- Profit distributions

### How are profits distributed to investors?

Profits are distributed proportionally based on your investment share in each pool. When a trader completes a trade:
1. The system calculates total profit/loss
2. Your proportional share is determined by your investment amount relative to the pool size
3. Profits are credited to your account balance

### Can I withdraw my investment?

Investment withdrawal policies depend on the specific investment terms. Active investments may have restrictions. Check your investment details or contact support for withdrawal options.

### How do I view my investment history?

Go to **Investor Portfolio** → **History** to see all your past investments, completed trades, and profit distributions. You can filter by timeframe (1 day, 1 week, 1 month, 1 year, all time).

### What happens if a trader's trade results in a loss?

Losses are distributed proportionally, just like profits. Your investment value decreases based on your share of the pool. All investors in the same pool share losses proportionally.

### How do I add traders to my watchlist?

Tap the eye icon (👁) on any trader's profile to add them to your watchlist. You can view your watchlist from the Investor Discovery view.

### Can I invest in multiple traders simultaneously?

Yes, you can create investments with multiple traders. Each investment is independent and tracked separately in your portfolio.

### I have another question about investments and portfolio.

Please contact our customer support team for assistance with investment-related questions not covered here.

---

## Trading and Depot Management (Trader)

### How do I execute a trade?

1. Navigate to **Trader Trading** view
2. Select "New Trade" or "Place Order"
3. Enter trade details:
   - Security symbol (WKN/ISIN)
   - Quantity
   - Price
   - Order type (market, limit)
   - Option details (if applicable)
4. Review pool participation (if active pool exists)
5. Submit the order

### What happens when I place a buy order with an active pool?

When you place a buy order:
1. Your desired quantity is checked against your cash balance
2. The system checks if an active investment pool exists
3. If a pool is active, the system calculates the maximum purchasable quantity for the pool (accounting for fees)
4. A single order is executed combining your quantity and the pool's calculated quantity
5. The pool participates proportionally based on investor contributions

### How is the pool's purchasable quantity calculated?

The system uses a binary search algorithm to calculate the maximum quantity the pool can purchase, accounting for:
- Order fees
- Exchange fees
- Foreign transaction costs (if applicable)
- The pool's available balance

The calculation ensures fees are properly accounted for before determining the final purchasable quantity.

### What is the difference between "Laufende Orders" and "Bestand"?

- **Laufende Orders (Active Orders)**: Shows orders with status "submitted", "executed", or "confirmed" that are still in progress
- **Bestand (Holdings)**: Shows completed trades that have been converted to holdings (status "completed")

### How do I track my trading performance?

View your trading dashboard to see:
- Total trading volume
- Daily P&L (Profit & Loss)
- Active positions
- Completed trades
- Performance analytics

### How do I manage my depot (portfolio)?

Navigate to **Trader Depot** view to see:
- Active orders and their status
- Current holdings (DepotBestand)
- Position details
- P&L for each position

### What are the different order statuses?

- **Status 1 (übermittelt/submitted)**: Order has been submitted
- **Status 2 (ausgeführt/executed)**: Order has been executed on the exchange
- **Status 3 (bestätigt/confirmed)**: Order execution has been confirmed
- **Status 4 (abgeschlossen/completed)**: Order is completed and position moves to holdings

### How do I add securities to my watchlist?

Search for a security and tap the eye icon (👁) to add it to your watchlist. You can access your watchlist from the Trading view.

### Can I cancel an order?

Yes, you can cancel orders that are still in "submitted" or "executed" status. Navigate to Active Orders and select "Cancel" on the order you wish to cancel.

### How are trades linked to investment pools?

When you place a buy order with an active pool:
1. A Trade is created from your buy order
2. The system records PoolTradeParticipation linking the pool to the trade
3. Investor allocations are calculated proportionally
4. When you place a sell order, it's added to the existing Trade
5. Upon completion, profits/losses are distributed to investors

### What happens to remaining balances after a trade?

Small remaining balances after fee calculations are handled according to system configuration. Typically, they remain in the pool for future trades or are distributed proportionally to investors.

### How do I view investor fund allocations?

Navigate to your Trading Dashboard to see:
- Active investment pools
- Total pool balances
- Number of active investors
- Pool participation in trades

### I have another question about trading and depot management.

Please contact our customer support team for assistance with trading-related questions not covered here.

---

## Risk Management and Compliance

### What is risk tolerance and why is it important?

Risk tolerance (assessed on a 1-10 scale) helps determine:
- Which traders you can invest with
- Which securities can be traded
- Appropriate investment strategies

It ensures investments align with your risk preferences and financial situation.

### How is my risk profile determined?

During registration, you complete a risk assessment that evaluates:
- Your investment experience
- Financial situation
- Investment goals
- Risk appetite

This results in a risk tolerance score from 1 (very conservative) to 10 (very aggressive).

### Can I change my risk tolerance after registration?

Yes, you can update your risk tolerance in Profile → Settings → Risk Profile. Note that this may affect which traders or investments are available to you.

### What restrictions apply based on risk tolerance?

- Lower risk tolerance (1-3): Access to conservative traders and low-risk securities
- Medium risk tolerance (4-7): Access to moderate-risk investments
- Higher risk tolerance (8-10): Access to aggressive trading strategies and high-risk securities

### Are there trading restrictions for traders?

Traders must have:
- Sufficient experience with leveraged products (if trading derivatives)
- Appropriate risk classification
- Compliance with app trading rules

### What KYC (Know Your Customer) information is required?

During registration, you must provide:
- Valid identification (passport or ID card)
- Proof of address
- Tax identification number
- Employment and income information
- Declarations regarding insider trading and money laundering

### How is my personal information protected?

FIN1 follows GDPR compliance standards:
- Data encryption (AES-256)
- Secure storage (Keychain integration)
- TLS 1.3 for network communication
- User consent management

### I have another question about risk management and compliance.

Please contact our customer support team for assistance with risk and compliance questions not covered here.

---

## Profit Distribution and Accounting

### How are profits calculated and distributed?

1. **Trade Completion**: When a trader completes a trade (both buy and sell orders executed)
2. **Profit Calculation**: System calculates total profit/loss = (Sell Price × Quantity) - (Buy Price × Quantity) - Fees
3. **Proportional Allocation**: Each investor's share is calculated based on their investment amount relative to the pool size
4. **Distribution**: Profits are credited to investor accounts proportionally

### How is my proportional share determined?

Your share = (Your Investment Amount / Total Pool Balance) × Total Profit/Loss

Example:
- Pool total: €10,000
- Your investment: €2,000 (20% of pool)
- Trade profit: €1,000
- Your share: €200 (20% of profit)

### When are profits credited to my account?

Profits are credited immediately upon trade completion. You can see the distribution in your Portfolio → History view.

### How are fees handled in profit calculations?

All trading fees (order fees, exchange fees, foreign costs) are deducted before profit calculation. The net profit after fees is what gets distributed to investors.

### Can I see a breakdown of fees for each trade?

Yes, trade details show:
- Order fees
- Exchange fees
- Foreign transaction costs (if applicable)
- Total fees deducted

### How are losses handled?

Losses are distributed proportionally, just like profits. If a trade results in a loss:
- Your investment value decreases
- The loss is proportional to your share of the pool
- You can see the loss reflected in your portfolio value

### What is the difference between gross profit and net profit?

- **Gross Profit**: Profit before fees
- **Net Profit**: Profit after all fees are deducted (this is what gets distributed)

### How do I view my profit/loss history?

Navigate to **Investor Portfolio** → **History** and filter by timeframe to see:
- Individual trade profits/losses
- Cumulative P&L
- Profit distributions over time

### Are there tax implications for profits?

Tax obligations depend on your jurisdiction and tax status. FIN1 provides transaction history and statements for tax reporting, but you should consult a tax advisor for specific tax questions.

### I have another question about profit distribution and accounting.

Please contact our customer support team for assistance with accounting-related questions not covered here.

---

## Documents and Notifications

### What types of documents are available?

FIN1 provides access to:
- **Account Statements**: Monthly account summaries
- **Trade Confirmations**: Details of executed trades
- **Invoices**: Trading fees and charges
- **Tax Documents**: Annual tax statements
- **Investment Reports**: Performance reports for your investments
- **Contracts**: Investment agreements and terms

### How do I access my documents?

Navigate to **Notifications & Documents** view (accessible from the main navigation) to see all available documents. Documents are organized by type and date.

### How long are documents available?

Documents are available for download for a specified period (typically 7 years for tax and legal documents). Check document expiry dates in the Documents view.

### What happens to read notifications?

Notifications are automatically archived after 24 hours of being read. You can access archived notifications from the Archive view.

### How do I download a document?

1. Navigate to **Notifications & Documents**
2. Select the document you want
3. Tap "Download" or the download icon
4. The document will be saved to your device

### What types of notifications will I receive?

- **Investment Notifications**: New investment opportunities, investment updates
- **Trade Notifications**: Trade executions, order confirmations
- **System Notifications**: Account updates, security alerts, app announcements

### Can I filter notifications by type?

Yes, use the filter options in the Notifications view:
- All
- Investments/Trades
- System
- Documents

### How do I mark a notification as read?

Tap on a notification to view its details. It will be automatically marked as read. Unread notifications show a badge indicator.

### I have another question about documents and notifications.

Please contact our customer support team for assistance with document-related questions not covered here.

---

## Technical and App Usage

### What are the system requirements for FIN1?

- **OS**: iOS 16.0 or later
- **Device**: iPhone or iPad
- **Internet**: Required for all operations
- **Biometric**: Face ID or Touch ID supported (optional)

### How do I update the app?

FIN1 updates are available through the App Store. You'll receive a notification when updates are available, or you can check manually in the App Store app.

### The app is not loading or responding. What should I do?

1. **Check your internet connection**: Ensure you have a stable internet connection
2. **Restart the app**: Close and reopen FIN1
3. **Restart your device**: Sometimes a device restart resolves issues
4. **Update the app**: Ensure you're using the latest version
5. **Contact support**: If issues persist, contact customer support with details

### How do I enable push notifications?

Push notifications are enabled by default. To manage notification settings:
1. Go to Profile → Settings → Notifications
2. Toggle notification types on/off as desired
3. Ensure notifications are enabled in iOS Settings → FIN1 → Notifications

### Can I use FIN1 offline?

FIN1 requires an internet connection for all operations. Some cached data may be viewable offline, but you cannot execute trades or create investments without connectivity.

### How do I report a bug or issue?

1. Navigate to Profile → Help & Support → Report Issue
2. Describe the issue in detail
3. Include screenshots if possible
4. Submit the report

### How do I provide feedback?

You can provide feedback through:
- Profile → Help & Support → Feedback
- App Store reviews
- Direct contact with customer support

### Is my data backed up?

Yes, your account data is securely stored on FIN1 servers and backed up regularly. However, ensure you keep important documents downloaded locally if needed.

### How do I log out of the app?

Navigate to Profile → Settings → Log Out. You'll be returned to the login screen.

### Can I use FIN1 on multiple devices?

Yes, you can log in to FIN1 on multiple iOS devices using the same account credentials. Your data will sync across devices.

### I have another question about technical issues or app usage.

Please contact our customer support team for assistance with technical questions not covered here.

---

## Security and Privacy

### How secure is my financial information?

FIN1 uses industry-standard security measures:
- **Encryption**: AES-256 encryption for sensitive data
- **Secure Storage**: Keychain integration for credentials
- **Network Security**: TLS 1.3 for all API communication
- **Biometric Authentication**: Face ID/Touch ID support
- **Regular Security Audits**: Ongoing security assessments

### What should I do if I suspect unauthorized access?

1. **Immediately change your password**: Profile → Settings → Change Password
2. **Enable biometric authentication** if not already enabled
3. **Review recent activity**: Check your account for any suspicious transactions
4. **Contact support**: Report the issue immediately to customer support
5. **Consider account suspension**: Support can temporarily suspend your account if needed

### How is my personal data used?

FIN1 follows GDPR principles:
- Data is used only for app operations and legal compliance
- You can request data access, correction, or deletion
- Data is not shared with third parties without consent
- See our Privacy Policy for complete details

### Can I delete my account?

Yes, you can request account deletion through Profile → Settings → Account → Delete Account. Note that:
- All investments must be closed or withdrawn first
- Some data may be retained for legal/compliance purposes
- Account deletion is permanent and cannot be undone

### How do I change my password?

1. Navigate to Profile → Settings → Security
2. Select "Change Password"
3. Enter your current password
4. Enter and confirm your new password
5. Save changes

### I have another question about security and privacy.

Please contact our customer support team for assistance with security-related questions not covered here.

---

## Contact and Support

### How can I contact customer support?

- **In-App**: Profile → Help & Support → Contact Support
- **Email**: support@fin1.com
- **Phone**: Available in-app under Help & Support
- **Help Center**: This FAQ and documentation

### What information should I provide when contacting support?

- Your account email or customer ID
- Description of the issue or question
- Screenshots (if applicable)
- Steps to reproduce (for technical issues)
- Device and iOS version

### What are your support hours?

Customer support is available:
- **Monday - Friday**: 9:00 AM - 6:00 PM (CET)
- **Saturday**: 10:00 AM - 2:00 PM (CET)
- **Sunday**: Closed

Emergency support is available 24/7 for security-related issues.

### Where can I find more detailed documentation?

- **In-App**: Profile → Help & Support → Documentation
- **Online**: Documentation section on FIN1 website
- **Engineering Guide**: See `Documentation/ENGINEERING_GUIDE.md` for technical details

---

## Legal and Regulatory

### What are the terms of service?

The complete Terms of Service are available:
- During registration (you must accept to proceed)
- Profile → Legal → Terms of Service
- Online documentation

### What is your privacy policy?

Our Privacy Policy explains how we collect, use, and protect your data:
- Profile → Legal → Privacy Policy
- Available during registration
- Online documentation

### Are there fees for using FIN1?

Fee structures vary by service:
- **Trading Fees**: Applied per trade (order fees, exchange fees)
- **Investment Fees**: May apply depending on investment type
- **Account Fees**: Check current fee schedule in Profile → Fees

All fees are disclosed before you confirm any transaction.

### What regulatory compliance does FIN1 follow?

FIN1 complies with:
- GDPR (General Data Protection Regulation)
- Financial services regulations applicable to investment apps
- KYC/AML (Know Your Customer/Anti-Money Laundering) requirements
- Tax reporting obligations

### I have another question about legal or regulatory matters.

Please contact our customer support team or legal department for assistance with legal questions not covered here.

---

**Last Updated**: [Current Date]

**Version**: 1.0

---

© 2024 FIN1 - Investment Pool App

For additional support, please contact our customer service team through the app or visit our support center.

