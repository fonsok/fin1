# Order vs Trade Flow Clarification

## The Correct Flow

The current architecture is **correct** but the naming can be confusing. Here's the proper flow:

### 1. User Clicks "Handeln" (Trade Button)
- **What happens**: User opens `SecuritiesSearchView`
- **What is created**: Nothing yet - just UI interaction

### 2. User Places Buy Order
- **What happens**: User fills out order form and clicks "Place Order"
- **What is created**: `OrderBuy` (status: submitted)
- **Where**: `BuyOrderViewModel.placeOrder()` → `TraderService.placeBuyOrder()`

### 3. Buy Order Executes
- **What happens**: Order status progresses through submitted → executed → confirmed
- **What is created**: Still just `OrderBuy` (status: completed)
- **Where**: `OrderStatusSimulationService` handles status progression

### 4. Buy Order Completes
- **What happens**: Order reaches "confirmed" status
- **What is created**: `Trade` (status: pending) - **This is where Trade is created!**
- **Where**: `TraderService.handleOrderCompletion()` → `TradeLifecycleService.createNewTrade()`

### 5. Trade Lifecycle
- **Pending**: Only buy order exists
- **Active**: Buy order + sell order exist
- **Completed**: Both orders completed
- **Cancelled**: Trade cancelled

## Key Points

1. **Trade is NOT created when user clicks "Handeln"**
2. **Trade is NOT created when order is placed**
3. **Trade IS created when buy order completes**
4. **Trade represents the complete trading cycle (buy + sell)**

## Current Implementation Status

✅ **Correct**: Order creation flow
✅ **Correct**: Trade creation timing (after order completion)
✅ **Correct**: Trade lifecycle management
✅ **Correct**: Invoice generation from completed orders

## Naming Clarification

- `createNewTrade()` - Creates Trade from completed buy order (correct)
- `placeBuyOrder()` - Creates OrderBuy (correct)
- `showOrderBuy` - Correctly named (shows order creation flow)

## Recommended Changes

1. **Rename state variable**: ✅ **COMPLETED** - `showNewTrade` → `showOrderBuy`
2. **Update comments**: Clarify that Trade is created after order completion
3. **Update documentation**: Make the flow clearer

## Testing

The tests are correctly testing the actual flow:
- `testCreateNewTrade()` tests Trade creation from completed buy order
- Order placement tests verify Order creation
- Integration tests verify the complete flow

## Conclusion

The architecture is correct. The issue is semantic confusion in naming and documentation, not the actual implementation.
