# Calculation Integration Guide (Consumer API + Dependencies)

Goal: Help reuse the existing calculation stack in another project by showing callable surfaces, required dependencies, and wiring patterns.

## Service/Dependency Map (who needs what)
- **ProfitCalculationService**: stateless; needs models `Invoice`, `Trade`, `CalculationConstants.FeeRates`, `FeeCalculationService`.
- **FeeCalculationService**: stateless; needs `CalculationConstants.FeeRates`.
- **CalculationGuardService**: singleton; relies on `ProfitCalculationService`, `InvoiceTaxCalculator`, `FeeCalculationService`, `CalculationValidationService`; uses `Invoice`/`InvoiceItem` types.
- **TradeCalculationService**: needs `ProfitCalculationService`, `InvoiceTaxCalculator`, `CalculationGuardService`, `FeeCalculationService`; models `Trade`, `Invoice`, `InvoiceItem`, `TransactionDetails`, `FeeDetail`.
- **InvestmentQuantityCalculationService**: needs `FeeCalculationService`, `CalculationConstants.SecurityDenominations`, `CalculationConstants.FeeRates`.
- **SecuritiesValueCalculator**: needs `FeeCalculationService`.
- **InvestorCollectionBillCalculationService**: needs `FeeCalculationService`, `CalculationConstants.FeeRates`, `CalculationConstants.SecurityDenominations`; models `InvestorCollectionBillInput/Output`, `InvestorFeeDetail`, `Invoice`, `Trade`.
- **InvestmentProfitCalculator**: needs `InvestorCollectionBillCalculationService`, `ProfitCalculationService`, `CalculationConstants.FeeRates`, services `InvoiceServiceProtocol`, `TradeLifecycleServiceProtocol`, `PotTradeParticipationServiceProtocol`; models `PotTradeParticipation`, `Investment`.
- **InvestorGrossProfitService**: needs `PotTradeParticipationServiceProtocol`, `TradeLifecycleServiceProtocol`, `InvoiceServiceProtocol`, `InvestmentServiceProtocol`, `InvestorInvestmentStatementAggregator`.
- **CommissionCalculationService**: needs `InvestorGrossProfitServiceProtocol` (injected), `CalculationConstants.FeeRates`.
- **InvestorInvestmentStatementAggregator**: needs `InvestorCollectionBillCalculationService`, `PotTradeParticipationServiceProtocol`, `TradeLifecycleServiceProtocol`, `InvoiceServiceProtocol`, `InvestmentServiceProtocol`, `CalculationConstants.FeeRates`.
- **AccountStatementViewModel**: needs `UserServiceProtocol`, `InvestorCashBalanceServiceProtocol`, `InvoiceServiceProtocol`, `ConfigurationServiceProtocol`, optional `TraderDataServiceProtocol`; uses `TraderAccountStatementBuilder`.
- **MonthlyAccountStatementViewModel**: same as above; also month/year params.
- **TraderAccountStatementBuilder**: needs `InvoiceServiceProtocol`, `ConfigurationServiceProtocol`; models `Invoice`, `AccountStatementEntry`.
- **MonthlyAccountStatementGenerator**: needs `AppServices` bundle: `investorCashBalanceService`, `invoiceService`, `configurationService`, `documentService`, `notificationService`; `user.role` to switch investor/trader.

## Minimal Type Contracts (expected fields)
- Invoice: `transactionType` (.buy/.sell), `type` (regular/creditNote), `totalAmount`, `nonTaxTotal`, `items: [InvoiceItem]`, `createdAt`, `tradeId`, `tradeNumber`, `invoiceNumber`, `customerId`.
- InvoiceItem: `itemType` (.securities/.tax/.orderFee/.exchangeFee/.foreignCosts/.commission), `quantity`, `unitPrice`, `totalAmount`, `description`.
- Trade: `buyOrder` (price, quantity, wkn/isin, optionDirection, underlyingAsset, strike, symbol), `sellOrders` (or `sellOrder` legacy), `totalQuantity`, `totalSoldQuantity`, `entryPrice`, `displayROI`, `id`, `tradeNumber`.
- Participation: `PotTradeParticipation` with `tradeId`, `investmentId`, `ownershipPercentage`, `allocatedAmount`.
- Investment: `id`, `amount`, `reservationStatus`, `status`.
- AccountStatementEntry: `title`, `subtitle?`, `occurredAt`, `amount`, `direction` (.credit/.debit), `category`, `reference`, `metadata`, `balanceAfter`, computed `signedAmount`.
- Constants: `CalculationConstants.FeeRates` (orderFeeRate/min/max; exchangeFeeRate/min/max; foreignCosts; traderCommissionRate), `CalculationConstants.SecurityDenominations` helpers.

## Wiring Patterns (new project)
- Bundle services in a small container/facade that exposes:
  - Fee/profit: `FeeCalculationService`, `ProfitCalculationService`, `CalculationGuardService`.
  - Trader calcs: `TradeCalculationService`, `InvestmentQuantityCalculationService`, `SecuritiesValueCalculator`.
  - Investor calcs: `InvestorCollectionBillCalculationService`, `InvestmentProfitCalculator`, `InvestorGrossProfitService`, `CommissionCalculationService`, `InvestorInvestmentStatementAggregator`.
  - Statements: `TraderAccountStatementBuilder`, `AccountStatementViewModel`, `MonthlyAccountStatementViewModel`, `MonthlyAccountStatementGenerator`.
- Provide adapters for `InvoiceServiceProtocol`, `TradeLifecycleServiceProtocol`, `PotTradeParticipationServiceProtocol`, `InvestorCashBalanceServiceProtocol`, `InvestmentServiceProtocol`, `ConfigurationServiceProtocol`, `NotificationService`, `DocumentService`, `UserServiceProtocol`.
- Keep `CalculationConstants` in one place and ensure parity for fees/denominations/commission rate.
- If distributing as a binary, expose a stable API surface that mirrors the consumer methods above; keep models either in a shared module or define thin DTOs and map internally.

## Validation & Guards to Preserve
- Enable `CalculationGuardService` in strict/warning mode during integration to catch divergences.
- Preserve invoice item filtering rules (profit excludes tax items; tax only tax items; fee calculations only fee items; securities only securities items).
- Maintain input validation on investor collection bill (positive capital/price/ownership/trade quantity; invoice quantity vs calculated quantity warning).

## Optional Facade Suggestion
Expose a single facade (e.g., `CalculationKit`) that:
- Configures constants.
- Accepts service providers (protocol-based) for invoices, trades, participations, investments, cash ledger, documents, notifications, users, configuration.
- Re-exports the main calculators and statement generators with stable DTOs.

### Sample Facade Shape (binary consumer)
- Module: `CalculationKit` (SwiftPM binary target / XCFramework)
- Public DTOs:
  - `CKInvoice { id, tradeId, tradeNumber, transactionType, type, totalAmount, nonTaxTotal, createdAt, customerId, items: [CKInvoiceItem] }`
  - `CKInvoiceItem { itemType, quantity, unitPrice, totalAmount, description }`
  - `CKTrade { id, tradeNumber, buyOrder: CKOrder, sellOrders: [CKOrder], totalQuantity, totalSoldQuantity, entryPrice, displayROI }`
  - `CKOrder { price, quantity, wknIsin, optionDirection, underlyingAsset, strike, symbol }`
  - `CKParticipation { tradeId, investmentId, ownershipPercentage, allocatedAmount }`
  - `CKInvestment { id, amount, reservationStatus, status }`
  - `CKAccountStatementEntry { title, subtitle, occurredAt, amount, direction, category, reference, metadata, balanceAfter }`
- Public services/protocols the host app implements:
  - `CKInvoiceService`, `CKTradeLifecycleService`, `CKParticipationService`, `CKInvestmentService`, `CKInvestorCashLedgerService`, `CKDocumentService`, `CKNotificationService`, `CKUserService`, `CKConfigurationService`.
- Public API examples:
  - `CalculationKit.profit.calculateTaxableProfit(buyInvoice:sellInvoices:)`
  - `CalculationKit.fees.calculateTotalFees(for:)`
  - `CalculationKit.investor.calculateCollectionBill(input:)`
  - `CalculationKit.investor.calculateTotals(participations:investmentCapital:)`
  - `CalculationKit.investor.getGrossProfit(investmentId:tradeId:)`
  - `CalculationKit.commission.calculateForTrade(tradeId:rate:)`
  - `CalculationKit.trader.calculateTradeBreakdown(trade:invoices:)`
  - `CalculationKit.trader.calculateMaxQuantity(...)`
  - `CalculationKit.statements.generateMonthly(for:)`
  - `CalculationKit.statements.buildAccountStatement(for:)`
- Configuration:
  - `CalculationKit.configure(constants: CKCalculationConstants, services: CKServiceProvider, guardMode: .strict|.warning|.disabled)`
  - Constants mirror `CalculationConstants.FeeRates` and `SecurityDenominations`.
- Notes:
  - Keep API stable; internal models can map to app models.
  - Provide deterministic behavior: pure calculations, no hidden state; guards enabled in staging to catch mismatches.


