# 🛡️ Securities Search Filter Protection Guide

> **Produktkontext (FIN1):** Die Suche und Filter beziehen sich auf **Derivate** (z. B. Optionsscheine, Zertifikate). Einträge wie „Aktien“, „EUR/USD“ oder „Bitcoin“ in Filterlisten sind **Basiswerte** (Underlying) oder Kategorien für solche Produkte — nicht die Behauptung, die App biete Kassamarkt-Aktienhandel, Spot-Forex oder unmittelbaren Krypto-Spot an.

## ⚠️ CRITICAL: ALL Filter Logic Must Not Be Broken Again

The securities search filter functionality was previously broken, causing search results to show incorrect data despite correct filter selection. This document outlines how to protect the ENTIRE filter system.

## 🔍 What Was Broken

- **Issue**: Search results showed wrong underlying assets despite correct filter selection
- **Root Cause**: Fallback logic in `SearchResult` initializer was triggered incorrectly
- **Impact**: Users saw incorrect data, breaking trust in the application
- **Scope**: This affected the entire filter system, not just basiswert

## 🛠️ How It Was Fixed

### 1. MockDataGenerator.swift
```swift
// CRITICAL: Always use the selected basiswert, fallback to DAX only if empty
let underlyingAsset = filters.basiswert.isEmpty ? "DAX" : filters.basiswert
```

### 2. SearchResult.swift
```swift
// CRITICAL: Use provided underlyingAsset if not empty, otherwise fallback to WKN mapping
if let underlyingAsset = underlyingAsset, !underlyingAsset.isEmpty {
    self.underlyingAsset = underlyingAsset
} else {
    self.underlyingAsset = Self.getUnderlyingAssetFromWKN(wkn)
}
```

### 3. SecuritiesSearchService.swift
```swift
// Clear previous results to prevent showing stale data
searchResults = []
```

## 🚨 Protection Rules

### 1. **Never Change These Files Without Tests**
- `MockDataGenerator.swift` - Lines 120-122 (basiswert logic)
- `SearchResult.swift` - Lines 31-38 (underlying asset logic)
- `SecuritiesSearchService.swift` - Line 59 (clear results)
- `SearchFilterService.swift` - All filter properties
- `SecuritiesSearchCoordinator.swift` - Search coordination logic
- `SecuritiesSearchViewModel.swift` - ViewModel filter bindings
- `SecuritiesSearchView.swift` - UI filter bindings
- `SearchFormSection.swift` - Form filter components
- `FilterSection.swift` - Dynamic filter components

### 2. **Always Run These Tests Before Committing**
```bash
# Run the comprehensive filter tests
xcodebuild test -project FIN1.xcodeproj -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FIN1Tests/SecuritiesSearchFilterTests

# Run the basiswert-specific tests
xcodebuild test -project FIN1.xcodeproj -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FIN1Tests/BasiswertFilterTests
```

### 3. **Manual Testing Checklist**
- [ ] **Category Filter**: Select "Optionsschein" → Results show "Optionsschein" category
- [ ] **Category Filter**: Test with any new categories added → Results show correct category
- [ ] **Basiswert Filter**: Test with any item from "Basiswerte" card → Results show correct underlying asset (**underlying of the derivative**, not “we trade spot equities/FX/crypto”)
  - [ ] Indices: DAX, MDAX, SDAX, TecDAX, FTSE 100, CAC 40, S&P 500, NASDAQ 100
  - [ ] Single-name underlyings (often shown as company names): Apple, BMW, SAP, Siemens, Volkswagen, Adidas, Allianz, BASF — **as basis for warrants/certificates**, if present in mock/UI lists
  - [ ] Metals: Gold, Silber, Platin, Palladium, Kupfer — **as underlying for derivative products**, if present
  - [ ] Other underlyings: EUR/USD, GBP/USD, Bitcoin, Ethereum (as available in lists) — **derivative-linked only**, not spot FX/crypto trading as a separate product line
- [ ] **Direction Filter**: Select "Call" → Results show "Call" direction
- [ ] **Direction Filter**: Select "Put" → Results show "Put" direction
- [ ] **Strike Price Gap Filter**: Select "Am Geld" → Results respect filter
- [ ] **Strike Price Gap Filter**: Select "Aus dem Geld" → Results respect filter
- [ ] **Restlaufzeit Filter**: Select "< 4 Wo." → Results respect filter
- [ ] **Restlaufzeit Filter**: Select "> 1 Jahr" → Results respect filter
- [ ] **Emittent Filter**: Test with any item from "Emittent" card → Results respect filter
  - [ ] Major banks: BNP Paribas, Citigroup, Société Générale, Goldman Sachs, Deutsche Bank
  - [ ] Other issuers: JPMorgan Chase, Morgan Stanley, UBS, Credit Suisse, Barclays, HSBC, ING, etc.
  - [ ] Note: List can change as issuers stop providing certain products
- [ ] **Omega Filter**: Select "> 10" → Results respect filter
- [ ] **Omega Filter**: Select "< 5" → Results respect filter
- [ ] **Combined Filters**: Multiple filters work together correctly
- [ ] **No Stale Results**: Previous search results are cleared when filters change
- [ ] **Dynamic Lists**: Test that new items added to filter lists work correctly
- [ ] **Discontinued Items**: Test that removed items from filter lists don't break the system

### 4. **Code Review Requirements**
- [ ] Any changes to filter logic must be reviewed by senior developer
- [ ] Must include test coverage for the changed functionality
- [ ] Must include manual testing verification
- [ ] Must verify all filter combinations work correctly

## 🧪 Test Coverage

The following tests must pass:

### SecuritiesSearchFilterTests
- `testCategoryFilterOptionsschein()`
- `testCategoryFilterAktien()` — **Note:** If the test name still references „Aktien“, treat it as a **category/label** in the search UI; product scope remains **derivatives**. Rename test when refactoring for clarity.
- `testBasiswertFilterWithFTSE100()`
- `testBasiswertFilterWithCAC40()`
- `testBasiswertFilterWithDAX()`
- `testEmptyBasiswertFallback()`
- `testDirectionFilterCall()`
- `testDirectionFilterPut()`
- `testStrikePriceGapFilterAmGeld()`
- `testStrikePriceGapFilterAusDemGeld()`
- `testRestlaufzeitFilterLessThan4Weeks()`
- `testRestlaufzeitFilterMoreThan1Year()`
- `testEmittentFilterSocieteGenerale()`
- `testEmittentFilterGoldmanSachs()`
- `testOmegaFilterHigh()`
- `testOmegaFilterLow()`
- `testCombinedFiltersFTSE100CallAmGeld()`
- `testCombinedFiltersDAXPutAusDemGeld()`
- `testSearchResultInitializerWithValidUnderlyingAsset()`
- `testSearchResultInitializerWithEmptyUnderlyingAsset()`
- `testSearchResultInitializerWithNilUnderlyingAsset()`
- `testFullSearchFlowWithAllFilters()`
- `testSearchResultsClearedOnNewSearch()`
- `testFilterManagerPublishesCorrectFilters()`
- `testFilterManagerDefaultValues()`

### BasiswertFilterTests
- `testBasiswertFilterWithFTSE100()`
- `testBasiswertFilterWithCAC40()`
- `testBasiswertFilterWithDAX()`
- `testEmptyBasiswertFallback()`
- `testSearchResultInitializerWithValidUnderlyingAsset()`
- `testSearchResultInitializerWithEmptyUnderlyingAsset()`
- `testSearchResultInitializerWithNilUnderlyingAsset()`
- `testFullSearchFlowWithBasiswertFilter()`
- `testSearchResultsClearedOnNewSearch()`

## 🔧 Debugging

If any filter breaks again:

1. **Check the logs** for these debug messages:
   ```
   🔍 DEBUG: SearchFilterService.basiswert changed from 'old' to 'new'
   🔍 DEBUG: SearchFilterService.direction changed from 'old' to 'new'
   🔍 DEBUG: MockDataGenerator.generateOptionsResults()
   🔍 DEBUG: filters.basiswert = 'FTSE 100'
   🔍 DEBUG: underlyingAsset = 'FTSE 100'
   🔍 DEBUG: SearchResult.init - provided underlyingAsset: FTSE 100
   🔍 DEBUG: SearchResult.init - final underlyingAsset: FTSE 100
   ```

2. **Verify the flow**:
   - FilterManager → SecuritiesSearchCoordinator → SecuritiesSearchService → MockDataGenerator → SearchResult

3. **Check for common issues**:
   - Empty string being passed instead of valid filter values
   - Fallback logic being triggered incorrectly
   - Stale results not being cleared
   - Filter combinations not working together
   - UI bindings not updating filter state

## 📝 Change Log

- **2026-04-04**: Product scope clarified in this doc — search/filters are **derivatives-first**; Basiswert lists describe **underlyings**, not cash-market equities/FX/crypto as standalone FIN1 products. Architecture/future-improvements wording aligned.
- **2025-10-12**: Initial basiswert filter fix implemented
- **2025-10-12**: Comprehensive filter protection added
- **2025-10-12**: All filter tests implemented
- **2025-10-12**: CI/CD protection for all filter files added
- **2025-10-12**: Complete documentation created

## 🚀 Future Improvements

- Consider adding integration tests that test the full UI flow
- Add performance tests to ensure filter changes don't impact search speed
- Consider adding telemetry to track filter usage and detect issues early
- Add filter validation to prevent invalid combinations
- Consider adding filter presets for common use cases

## 🎯 Filter System Architecture

```
SecuritiesSearchView
├── SearchFormSection (Category, Basiswert, Direction)
├── FilterSection (Strike Price Gap, Restlaufzeit, Emittent, Omega)
└── ChipFlowLayout (Selected Filters Display)

SecuritiesSearchViewModel
├── SearchFilterService (Filter State Management)
├── SecuritiesSearchCoordinator (Search Coordination)
└── SecuritiesSearchService (Search Execution)

MockDataGenerator
├── generateOptionsResults() (Options / derivative-style filtering)
├── generateStockResults() — **Legacy name:** if still present, it should only feed **derivative** mock rows (e.g. category labels), not a separate “cash stock trading” mode
└── SearchResult Creation (Result Generation)

Dynamic Filter Lists (can change over time):
├── Category List (e.g. Optionsschein, weitere **Derivat**-Typen wenn das Produkt erweitert wird — **nicht** als Roadmap für Kassamarkt-Aktien, Spot-Forex oder freistehende CFD-/Futures-Brokerage ohne Produktentscheid)
├── Basiswert List (Indices, **Einzelwerte** als Underlying, Rohstoffe, FX-/Krypto-**Bezug** in Zertifikaten/OS — sprachlich als Underlyings für Derivate, nicht als „wir handeln alles“)
├── Emittent List (Banks, Investment firms, etc.)
└── Other Filter Lists (Strike Price Gap, Restlaufzeit, Omega, etc.)
```

## 🔄 Dynamic Filter Management

### Key Principles:
1. **Filter lists are dynamic** - items can be added/removed over time
2. **Issuer availability changes** - some issuers may stop providing certain products
3. **New underlying assets** - new indices, single-name underlyings, metals, etc. can be added **for derivative search**
4. **Category expansion** - new **derivative** product categories can be introduced when product/legal allows
5. **Filter logic must remain robust** - regardless of list changes

### Protection Strategy:
- Tests use representative examples, not exhaustive lists
- Filter logic is validated for any valid input, not specific values
- System gracefully handles missing/discontinued items
- New items automatically work with existing filter logic

---

**Remember**: This functionality is critical to user trust. Any changes must be thoroughly tested and reviewed. The entire filter system must work correctly together.
