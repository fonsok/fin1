# Sell Invoice Fee Behavior Confirmation

## Current Implementation (Correct)
The current implementation correctly **subtracts** fees for sell orders, which is the proper behavior.

## Implementation Details
In `InvoiceFactory.swift`, the `isSellOrder` parameter is correctly set to `true` for sell orders, which causes fees to be negative (subtracted).

### Current Implementation (Correct):
```swift
// In InvoiceFactory.swift line 69
items.append(contentsOf: createFeeItems(for: sellOrder.totalAmount, isSellOrder: true))
```

This passes `isSellOrder: true`, which results in `isNegative: true` being passed to the fee calculator methods, making fees negative (subtracted).

## Why This Is Correct

### Business Logic
- **Sell Orders**: Fees are subtracted because they reduce the net proceeds to the seller
- **Buy Orders**: Fees are added because they increase the total cost to the buyer
- **Financial Impact**: This correctly reflects how fees affect each transaction type

### Fee Calculation Logic
The `InvoiceFeeCalculator` methods work as follows:

```swift
static func createOrderFeeItem(for orderAmount: Double, isNegative: Bool = false) -> InvoiceItem {
    let amount = calculateOrderFee(for: orderAmount)
    return InvoiceItem(
        description: "Ordergebühr",
        quantity: 1,
        unitPrice: isNegative ? -amount : amount,  // ← This determines if fee is positive or negative
        itemType: .orderFee
    )
}
```

## Example Calculation

For a €1000 sell order:

### Current Implementation (Correct)
- Securities Value: €1,000.00
- Order Fee: -€5.00 (subtracted from proceeds)
- Exchange Fee: -€1.00 (subtracted from proceeds)
- Foreign Costs: -€1.50 (subtracted from proceeds)
- **Net Proceeds: €992.50** (what the seller actually receives)

### If Fees Were Added (Incorrect)
- Securities Value: €1,000.00
- Order Fee: +€5.00 (incorrectly added)
- Exchange Fee: +€1.00 (incorrectly added)
- Foreign Costs: +€1.50 (incorrectly added)
- **Total: €1,007.50** (incorrect - seller would pay more than they receive)

## Impact

The current implementation correctly ensures that:
1. **Sell invoices show fees as deductions** (negative values) from the sale proceeds
2. **The invoice total reflects the net amount** the seller actually receives
3. **Users see the correct net proceeds** after fees are deducted
4. **Financial calculations are accurate** for accounting and tax purposes
5. **Business logic is consistent** with how trading fees work in practice

## Files Status

1. `FIN1/Features/Trader/Models/InvoiceFactory.swift` - **Correctly implemented** with `isSellOrder: true` for sell orders

## Conclusion

The sell invoice fee calculation correctly **subtracts** fees from the sale proceeds, ensuring accurate financial reporting and proper net proceeds calculation for sell transactions. This is the standard and correct behavior for trading platforms.
