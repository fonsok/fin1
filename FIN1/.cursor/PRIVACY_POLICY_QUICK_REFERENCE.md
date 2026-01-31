# Privacy Policy Quick Reference - FIN1

## Essential Sections Checklist

### ✅ Required for GDPR/DSGVO Compliance

1. **Controller Information**
   - Company name, address, registration
   - DPO contact (if required)
   - Policy version & date

2. **Data Categories** (19 categories for FIN1)
   - Personal identification
   - Contact information
   - Financial data
   - Identity documents (special category)
   - Trading/investment data
   - Account/authentication
   - Behavioral/usage
   - Communication
   - Legal/compliance

3. **Legal Basis** (Art. 6 GDPR)
   - Contract performance
   - Legal obligation (KYC/AML, tax)
   - Legitimate interests
   - Consent (marketing)

4. **Purpose of Processing**
   - Service provision
   - Legal compliance
   - Security/fraud prevention
   - Communication
   - Business operations
   - Marketing (with consent)

5. **Data Sharing**
   - Parse Server, MongoDB, PostgreSQL
   - Brokers/exchanges
   - Regulatory authorities (BaFin, tax)
   - Service providers (APNS, FCM, analytics)

6. **International Transfers**
   - EU-US transfers (SCCs, Data Privacy Framework)
   - Third countries
   - Safeguards

7. **Data Retention**
   - Financial records: 10 years (tax law)
   - Trading records: 10 years (WpHG)
   - KYC documents: 5-10 years (AML)
   - Account data: While active + retention period

8. **User Rights** (GDPR Chapter III)
   - Access (Art. 15)
   - Rectification (Art. 16)
   - Erasure (Art. 17) - with limitations
   - Restrict processing (Art. 18)
   - Data portability (Art. 20)
   - Object (Art. 21)
   - Automated decisions (Art. 22)
   - Withdraw consent (Art. 7)
   - Lodge complaint (Art. 77)

9. **Security Measures**
   - AES-256 encryption
   - TLS 1.3
   - Keychain integration
   - Biometric authentication
   - Access controls

10. **Cookies & Tracking**
    - Essential cookies
    - Analytics cookies (consent)
    - Marketing cookies (consent)
    - Mobile app tracking

11. **Data Breach Notification**
    - User notification (72 hours if high risk)
    - Authority notification (72 hours)
    - Breach register

12. **Contact Information**
    - DPO email/phone
    - Privacy inquiries
    - How to exercise rights

### ✅ Required for US Privacy Laws (if applicable)

1. **CCPA Rights** (California)
   - Right to know
   - Right to delete
   - Right to opt-out
   - Non-discrimination

2. **State-Specific Rights**
   - Virginia (VCDPA)
   - Colorado (CPA)
   - Connecticut (CTDPA)

3. **Financial Services** (if applicable)
   - GLBA compliance
   - FINRA requirements
   - SEC regulations

---

## FIN1-Specific Data Categories

### High-Priority Categories

1. **Identity Documents** (Special Category - Art. 9)
   - Passport images
   - ID card images
   - Address verification
   - Legal basis: Legal obligation (KYC/AML)

2. **Financial Data**
   - Tax numbers
   - Income information
   - Investment amounts
   - Trading records
   - Legal basis: Contract + Legal obligation

3. **Trading Data**
   - Orders (buy/sell)
   - Securities holdings
   - Profit/loss
   - Retention: 10 years (WpHG)

4. **KYC/AML Data**
   - Verification documents
   - Compliance records
   - Retention: 5-10 years (GwG)
   - Limited deletion rights

5. **Investment Pool Data**
   - Proportional sharing among participants
   - Transparency requirements
   - Anonymization where possible

---

## Legal Basis Mapping for FIN1

| Data Category | Primary Legal Basis | Secondary Basis |
|--------------|-------------------|-----------------|
| Personal identification | Contract (Art. 6(1)(b)) | Legal obligation (KYC) |
| Contact information | Contract | - |
| Financial data | Contract + Legal obligation | - |
| Identity documents | Legal obligation (KYC/AML) | - |
| Trading data | Contract | Legal obligation (WpHG) |
| KYC/AML data | Legal obligation (GwG) | - |
| Account data | Contract | - |
| Usage analytics | Legitimate interests | Consent (optional) |
| Marketing data | Consent | - |
| Legal documents | Legal obligation | Contract |

---

## Retention Periods Summary

| Data Type | Retention Period | Legal Basis |
|-----------|-----------------|-------------|
| Financial records | 10 years | German tax law |
| Trading records | 10 years | WpHG § 34 |
| Invoices | 10 years | German tax law |
| KYC documents | 5-10 years | GwG (AML) |
| Account data (active) | While active | Contract |
| Account data (closed) | 10 years (financial) | Tax law |
| Marketing consent | Until withdrawal + 3 years | GDPR |
| Analytics data | 2-3 years (anonymized after 1) | Legitimate interests |

---

## Third-Party Disclosure Checklist

### Service Providers (Processors)
- [ ] Parse Server (backend)
- [ ] MongoDB (database)
- [ ] PostgreSQL (analytics)
- [ ] Redis (caching)
- [ ] MinIO/S3 (file storage)
- [ ] Cloud hosting (AWS/Azure/etc.)
- [ ] Email service providers
- [ ] APNS (Apple Push Notifications)
- [ ] FCM (Google Firebase Cloud Messaging)
- [ ] Analytics service (internal)

### Financial Institutions
- [ ] Brokers (order execution)
- [ ] Exchanges (XETRA, etc.)
- [ ] Payment processors (if applicable)

### Regulatory Authorities
- [ ] BaFin (German financial authority)
- [ ] Tax authorities
- [ ] Law enforcement (if required)
- [ ] Courts (if court order)

---

## User Rights Exercise Methods

### How Users Can Exercise Rights

1. **In-App**
   - Profile → Settings → Privacy
   - Support → Privacy Request
   - Data export feature (if implemented)

2. **Email**
   - privacy@fin1.com
   - dpo@fin1.com

3. **Written Request**
   - Postal address provided
   - Identity verification required

### Response Timeline
- **Standard Request**: 1 month
- **Complex Request**: Up to 3 months (with notification)
- **Fees**: Generally free (may charge for excessive requests)

---

## Jurisdiction-Specific Requirements

### German Users
- **Primary Law**: GDPR, DSGVO, BDSG
- **Language**: German version required
- **Authority**: BfDI or state authority
- **Retention**: German tax/regulatory requirements

### US Users (if applicable)
- **CCPA**: California residents
- **State Laws**: Virginia, Colorado, Connecticut, etc.
- **Opt-Out**: Different from EU opt-in
- **Financial Services**: GLBA if applicable

---

## Critical Compliance Points

### ⚠️ High-Risk Areas

1. **Identity Documents**
   - Special category data (Art. 9)
   - Explicit consent or legal obligation required
   - Enhanced security measures

2. **Financial Data**
   - Sensitive by nature
   - Long retention (10 years)
   - Limited deletion rights

3. **KYC/AML Data**
   - Cannot delete while legally required
   - Must explain limited deletion rights
   - Regulatory sharing requirements

4. **International Transfers**
   - EU-US transfers require safeguards
   - SCCs or Data Privacy Framework
   - User rights to object

5. **Automated Decisions**
   - Risk assessment algorithms
   - Trader matching algorithms
   - Right to human review

---

## Policy Update Triggers

Update Privacy Policy when:
- [ ] New data categories added
- [ ] New third parties added
- [ ] New processing purposes
- [ ] Legal requirements change
- [ ] Business model changes
- [ ] New jurisdictions entered
- [ ] Security measures change

---

## Implementation Priority

### Phase 1: Essential (MVP)
1. Controller information
2. Data categories (all 19)
3. Legal basis (for each category)
4. Purpose of processing
5. User rights (all 9 rights)
6. Contact information
7. Security measures

### Phase 2: Compliance
8. Data sharing (all third parties)
9. International transfers
10. Data retention (all periods)
11. Cookies & tracking
12. Data breach notification

### Phase 3: Enhanced
13. Profiling & automated decisions
14. Marketing & communications
15. Children's privacy
16. Jurisdiction-specific sections

---

## Quick Legal Basis Reference

**Art. 6(1)(a) - Consent**: Marketing, optional analytics
**Art. 6(1)(b) - Contract**: Account, trading, investment services
**Art. 6(1)(c) - Legal Obligation**: KYC, AML, tax, WpHG
**Art. 6(1)(f) - Legitimate Interests**: Security, fraud prevention, analytics

**Art. 9 - Special Category**: Identity documents (biometric data)
- Legal basis: Legal obligation (KYC/AML) or explicit consent

---

## Contact Information Template

```
Data Controller:
FIN1 [Company Name]
[Registered Address]
[Registration Number]

Data Protection Officer:
[Name]
Email: dpo@fin1.com
Phone: +49 [number]

Privacy Inquiries:
Email: privacy@fin1.com
Support: In-app support feature

Supervisory Authority (Germany):
Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (BfDI)
[Address]
Website: [URL]
```

---

**Last Updated**: [Date]
**Next Review**: [Date + 1 year]





