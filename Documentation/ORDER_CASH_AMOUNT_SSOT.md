# Order cash amount — SSOT

## Rule

All **order cash** (affordability caps, `estimatedCost`, `executePairedBuy` amounts, fee base) uses:

```text
gross EUR = Stück × Brief-Kurs (pricePerSecurity)
```

Swift: `OrderCashAmount.grossAmount(quantity:briefPricePerPiece:)`.

## Not allowed for cash

Do **not** compute a “price per unit” as `briefPrice / subscriptionRatio` for caps or balances.
That was the root cause of the UB4PQLG regression (1000 Stück capped to 60).

`subscriptionRatio` is only for:

- share display (`OrderCashAmount.shares(fromPieces:subscriptionRatio:)`)
- denomination steps (`CalculationConstants.SecurityDenominations`)

## Paired buy

- **Trader leg** → depot position quantity = `traderQuantity` (Stück).
- **Mirror pool leg** → separate trade/accounting; **not** a second depot row (`TraderDepotTradeFilter`).

## Guards

- Unit tests: `InvestmentQuantityCalculationServiceTests`, `BuyOrderQuantityPipelineTests`
- CI: `scripts/check-order-cash-amount-ssot.sh`
- SwiftLint (warning): custom rule `no_subscription_ratio_order_cash`

## Related (separate topic)

Trader **commission display** in the trades overview is documented in [`TRADER_COMMISSION_DISPLAY_SSOT.md`](TRADER_COMMISSION_DISPLAY_SSOT.md) — not order-cash / quantity caps.
