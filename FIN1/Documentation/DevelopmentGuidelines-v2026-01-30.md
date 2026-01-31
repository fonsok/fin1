# Development Guidelines

## Data Flow Validation

### Critical Rules

1. **Never use hardcoded defaults** in production code
   - ❌ `underlyingAsset = description ?? "DAX"`
   - ✅ `underlyingAsset = description` (with validation)

2. **Always validate data flow** at critical points
   - Use `DataFlowValidator` before creating orders
   - Log data flow with `DataFlowValidator.logDataFlow()`
   - Fail fast with clear error messages

3. **Test critical user flows** with integration tests
   - Test complete flows from UI selection to data persistence
   - Test edge cases and error conditions
   - Run integration tests before merging

### Data Flow Checklist

Before implementing any feature that involves data flow:

- [ ] Identify all data transformation points
- [ ] Add validation at each transformation
- [ ] Add structured logging for debugging
- [ ] Write integration tests for the complete flow
- [ ] Test with different input values
- [ ] Verify no hardcoded defaults exist

### Common Pitfalls to Avoid

1. **Silent Failures**: Always validate and fail fast
2. **Hardcoded Defaults**: Use actual data or explicit errors
3. **Missing Validation**: Validate at every transformation point
4. **Inconsistent Logging**: Use structured logging consistently
5. **Untested Flows**: Write integration tests for critical paths

### Debugging Data Flow Issues

1. Check console logs for `🔄 DATA FLOW` messages
2. Look for `⚠️ WARNING` or `❌ ERROR` messages
3. Use `DataFlowValidator.validateSearchResult()` to test individual objects
4. Run integration tests to verify complete flows

### Example: Adding a New Feature

```swift
// 1. Add validation
let validationResult = data.validate(context: "NewFeature")
switch validationResult {
case .valid: break
case .warning(let message): print("⚠️ \(message)")
case .error(let message): throw AppError.validationError(message)
}

// 2. Add logging
DataFlowValidator.logDataFlow(
    step: "NewFeature processing",
    searchResult: data
)

// 3. Write integration test
func testNewFeatureFlow() async throws {
    // Test complete flow
}
```
