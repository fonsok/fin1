# Trade/Order/DepotBestand Architecture

## Overview

This document outlines the improved architecture for the trading system, clarifying the relationships between **Trade**, **Order**, and **DepotBestand** models.

## Architecture Components

### 1. **Order** - Individual Transactions
- **Purpose**: Individual buy/sell transactions with statuses and option details
- **Location**: Shown in "Laufende Orders" section of TraderDepotView
- **Status Progression**:
  - **Buy Orders**: submitted → executed → completed
  - **Sell Orders**: submitted → executed → confirmed

### 2. **Trade** - Complete Trading Cycle
- **Purpose**: Buy + Sell order results for investor pool distribution
- **Lifecycle**:
  1. Created from buy order (status: pending)
  2. Sell order added (status: active)
  3. Both orders completed (status: completed)
  4. Moved to DepotBestand (holdings)

### 3. **DepotBestand** - Holdings
- **Purpose**: Holdings with split option information (final state after trade completion)
- **Location**: Shown in "Bestand" section of TraderDepotView
- **Creation**: Generated from completed Trades using `DepotBestand.from(completedTrade:position:)`

## Data Flow

```
Active Orders → "Laufende Orders" section
     ↓
Completed Trades → Converted to DepotBestand → "Bestand" section
     ↓
Status 4 = Order completed, position moves to holdings
```

## Implementation Details

### Order Status Codes
- **1** = übermittelt (submitted)
- **2** = Handel ausgesetzt (suspended) / ausgeführt (executed)
- **3** = ausgeführt (executed) / bestätigt (confirmed)
- **4** = abgeschlossen (completed) - **Position moves to holdings**

### Model Relationships

```swift
// Order → Trade (when buy order is completed)
Trade.from(buyOrder: OrderBuy) -> Trade

// Trade → DepotBestand (when trade is completed)
DepotBestand.from(completedTrade: Trade, position: Int) -> DepotBestand
```

### Key Methods

#### Trade Model
- `Trade.from(buyOrder:)` - Creates trade from buy order
- `Trade.with(sellOrder:)` - Adds sell order to trade
- `Trade.updateStatus()` - Updates trade status based on order statuses

#### DepotBestand Model
- `DepotBestand.from(completedTrade:position:)` - Creates holdings from completed trade

## UI Sections

### "Laufende Orders" (Running Orders)
- Shows active orders with status progression
- Individual buy/sell transactions
- Status indicators and action buttons

### "Bestand" (Holdings)
- Shows completed trades converted to holdings
- Split option information (Call/Put, underlying asset)
- Position details and profit/loss calculations

## Benefits

1. **Clear Separation**: Orders handle individual transactions, Trades handle complete cycles
2. **Status Tracking**: Clear progression from order → trade → holdings
3. **Data Integrity**: Proper conversion between model types
4. **UI Clarity**: Clear distinction between running orders and holdings
5. **Architecture Compliance**: Follows MVVM and DI patterns

## Migration Notes

- Updated terminology: "Laufende Transaktionen" → "Laufende Orders"
- Enhanced model documentation with architecture overview
- Improved data flow with proper model conversions
- Added comprehensive status tracking and progression

