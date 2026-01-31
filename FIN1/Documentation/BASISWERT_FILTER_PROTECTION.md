# 🛡️ Basiswert Filter Protection Guide

## ⚠️ CRITICAL: This Logic Must Not Be Broken Again

The basiswert filter functionality was previously broken, causing search results to show incorrect underlying assets (e.g., showing "CAC 40" when "FTSE 100" was selected). This document outlines how to protect this critical functionality.

## 🔍 What Was Broken

- **Issue**: Search results showed wrong underlying assets despite correct filter selection
- **Root Cause**: Fallback logic in `SearchResult` initializer was triggered incorrectly
- **Impact**: Users saw incorrect data, breaking trust in the application

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
- `MockDataGenerator.swift` - Lines 120-122
- `SearchResult.swift` - Lines 31-38
- `SecuritiesSearchService.swift` - Line 59

### 2. **Always Run These Tests Before Committing**
```bash
# Run the specific basiswert filter tests
xcodebuild test -project FIN1.xcodeproj -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:FIN1Tests/BasiswertFilterTests
```

### 3. **Manual Testing Checklist**
- [ ] Select "FTSE 100" → Results show "FTSE 100" in Basiswert column
- [ ] Select "CAC 40" → Results show "CAC 40" in Basiswert column
- [ ] Select "DAX" → Results show "DAX" in Basiswert column
- [ ] Switch between different basiswert selections → Results update correctly
- [ ] No stale results from previous searches

### 4. **Code Review Requirements**
- [ ] Any changes to filter logic must be reviewed by senior developer
- [ ] Must include test coverage for the changed functionality
- [ ] Must include manual testing verification

## 🧪 Test Coverage

The following tests must pass:
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

If the basiswert filter breaks again:

1. **Check the logs** for these debug messages:
   ```
   🔍 DEBUG: MockDataGenerator.generateOptionsResults()
   🔍 DEBUG: filters.basiswert = 'FTSE 100'
   🔍 DEBUG: underlyingAsset = 'FTSE 100'
   🔍 DEBUG: SearchResult.init - provided underlyingAsset: FTSE 100
   🔍 DEBUG: SearchResult.init - final underlyingAsset: FTSE 100
   ```

2. **Verify the flow**:
   - FilterManager → SecuritiesSearchCoordinator → SecuritiesSearchService → MockDataGenerator → SearchResult

3. **Check for common issues**:
   - Empty string being passed instead of valid basiswert
   - Fallback logic being triggered incorrectly
   - Stale results not being cleared

## 📝 Change Log

- **2025-10-12**: Initial fix implemented
- **2025-10-12**: Protection tests added
- **2025-10-12**: Documentation created

## 🚀 Future Improvements

- Consider adding integration tests that test the full UI flow
- Add performance tests to ensure filter changes don't impact search speed
- Consider adding telemetry to track filter usage and detect issues early

---

**Remember**: This functionality is critical to user trust. Any changes must be thoroughly tested and reviewed.
