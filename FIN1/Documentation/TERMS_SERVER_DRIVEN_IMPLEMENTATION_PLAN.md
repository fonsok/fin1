# Terms of Service - Server-Driven Hybrid Implementation Plan

## Overview

This document outlines the implementation plan for migrating Terms of Service to a hybrid server-driven approach, combining server-fetched content with bundled fallbacks.

## Architecture Decision

**Approach**: Hybrid Server-Driven with 3-Tier Fallback
1. **Primary**: Fetch from Parse Server (latest version)
2. **Secondary**: Use cached version (last successful fetch)
3. **Tertiary**: Use bundled version (app fallback)

## Implementation Phases

### Phase 1: Backend Setup (Parse Server)

#### 1.1 Create TermsContent Parse Class

**Schema:**
```javascript
// Parse Class: TermsContent
{
  version: String (required, indexed),
  language: String (required, "en" | "de"),
  documentType: String (required, "terms" | "privacy"),
  effectiveDate: Date (required),
  isActive: Boolean (required, default: true),
  sections: Array (required), // Array of section objects
  createdAt: Date,
  updatedAt: Date
}
```

**Section Structure:**
```javascript
{
  id: String,
  title: String,
  content: String, // Markdown format
  icon: String
}
```

#### 1.2 Create Cloud Function for Current Terms

**File**: `backend/parse-server/cloud/main.js`

```javascript
Parse.Cloud.define("getCurrentTerms", async (request) => {
  const { language, documentType } = request.params;

  const query = new Parse.Query("TermsContent");
  query.equalTo("language", language || "en");
  query.equalTo("documentType", documentType || "terms");
  query.equalTo("isActive", true);
  query.descending("effectiveDate");
  query.limit(1);

  const result = await query.first({ useMasterKey: true });

  if (!result) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "No active terms found"
    );
  }

  return result.toJSON();
});
```

#### 1.3 Admin Interface for Terms Management

- Parse Dashboard can be used for initial setup
- Future: Custom admin UI for editing Terms
- Support for versioning and rollback

### Phase 2: Client-Side Service Layer

#### 2.1 TermsContentService Protocol

**File**: `FIN1/Shared/Services/TermsContentServiceProtocol.swift`

```swift
protocol TermsContentServiceProtocol {
    func fetchCurrentTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: DocumentType
    ) async throws -> TermsContent

    func getCachedTerms(
        language: TermsOfServiceDataProvider.Language,
        documentType: DocumentType
    ) -> TermsContent?

    func cacheTerms(_ terms: TermsContent)

    func clearCache()
}

enum DocumentType: String {
    case terms = "terms"
    case privacyPolicy = "privacy"
}
```

#### 2.2 TermsContent Model

**File**: `FIN1/Shared/Models/TermsContent.swift`

```swift
struct TermsContent: Codable {
    let version: String
    let language: String
    let documentType: String
    let effectiveDate: Date
    let isActive: Bool
    let sections: [TermsSection]

    enum CodingKeys: String, CodingKey {
        case version
        case language
        case documentType
        case effectiveDate
        case isActive
        case sections
        case objectId
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        language = try container.decode(String.self, forKey: .language)
        documentType = try container.decode(String.self, forKey: .documentType)

        // Parse date
        let dateString = try container.decode(String.self, forKey: .effectiveDate)
        let formatter = ISO8601DateFormatter()
        effectiveDate = formatter.date(from: dateString) ?? Date()

        isActive = try container.decode(Bool.self, forKey: .isActive)
        sections = try container.decode([TermsSection].self, forKey: .sections)
    }
}
```

#### 2.3 TermsContentService Implementation

**File**: `FIN1/Shared/Services/TermsContentService.swift`

**Key Features:**
- Fetches from Parse Server via ParseAPIClient
- Caches to UserDefaults (with version key)
- Falls back to bundled content
- Handles commission rate injection
- Supports offline mode

### Phase 3: Update TermsOfServiceViewModel

#### 3.1 Modify ViewModel to Use Service

**Changes:**
- Inject `TermsContentService` instead of using static content
- Load terms on view appear
- Handle loading states
- Support pull-to-refresh

#### 3.2 Commission Rate Injection

**Strategy:**
- Server returns template with `{{COMMISSION_RATE}}` placeholder
- Client replaces with actual rate from `ConfigurationService`
- Or: Server includes rate in response (requires server to know current rate)

### Phase 4: Caching Strategy

#### 4.1 Cache Implementation

**Storage**: UserDefaults with versioned keys
```swift
private func cacheKey(language: Language, documentType: DocumentType) -> String {
    "terms_cache_\(language.rawValue)_\(documentType.rawValue)"
}
```

**Cache Invalidation:**
- On version change
- On manual refresh
- After 24 hours (optional)

#### 4.2 Cache Structure

```swift
struct CachedTermsContent: Codable {
    let content: TermsContent
    let cachedAt: Date
    let version: String
}
```

### Phase 5: Migration Strategy

#### 5.1 Backward Compatibility

- Keep bundled Terms as fallback
- Existing users see bundled version until server version available
- New users get server version immediately

#### 5.2 Gradual Rollout

1. **Week 1**: Deploy backend, test with admin users
2. **Week 2**: Enable for 10% of users (feature flag)
3. **Week 3**: Enable for 50% of users
4. **Week 4**: Full rollout

### Phase 6: Testing

#### 6.1 Unit Tests

- TermsContentService: Fetch, cache, fallback
- Commission rate injection
- Version comparison logic

#### 6.2 Integration Tests

- Parse Server communication
- Offline mode behavior
- Cache invalidation

#### 6.3 E2E Tests

- User acceptance flow with server terms
- Offline acceptance flow
- Version update flow

## Data Flow

```
┌─────────────┐
│  App Launch │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Check Cache         │
│ (UserDefaults)      │
└──────┬──────────────┘
       │
       ├─ Cache Hit? ──► Use Cached ──► Display
       │
       └─ Cache Miss ──►
                        │
                        ▼
              ┌──────────────────┐
              │ Fetch from Server │
              │ (Parse Cloud)     │
              └──────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    Success                  Failure
         │                       │
         ▼                       ▼
    Cache Result         Use Bundled
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
                 Display
```

## Commission Rate Handling

### Option A: Client-Side Injection (Recommended)

**Server Template:**
```json
{
  "content": "Trader commissions ({{COMMISSION_RATE}}%, configurable)..."
}
```

**Client Replacement:**
```swift
func injectCommissionRate(
    _ content: String,
    rate: Double
) -> String {
    let percentage = Int(rate * 100)
    return content.replacingOccurrences(
        of: "{{COMMISSION_RATE}}",
        with: "\(percentage)"
    )
}
```

**Pros:**
- Server doesn't need to know current rate
- Rate changes don't require Terms update
- Simpler server logic

**Cons:**
- Template syntax in Terms content
- Client must handle replacement

### Option B: Server-Side Injection

**Server fetches rate from ConfigurationService and injects**

**Pros:**
- Cleaner Terms content
- Server controls formatting

**Cons:**
- Server needs access to config
- Terms update when rate changes (may not be desired)

## Security Considerations

1. **HTTPS Only**: All Terms fetches must use HTTPS
2. **Certificate Pinning**: Consider for production
3. **Content Validation**: Verify Terms structure before caching
4. **Version Verification**: Ensure version matches expected format
5. **Rate Limiting**: Prevent abuse of Terms endpoint

## Performance Optimization

1. **Background Fetch**: Load Terms on app launch (non-blocking)
2. **Prefetch**: Fetch Terms when user opens Profile tab
3. **Compression**: Gzip Terms content on server
4. **CDN**: Consider CDN for Terms content (future)

## Monitoring & Analytics

1. **Fetch Success Rate**: Track server fetch success/failure
2. **Cache Hit Rate**: Monitor cache effectiveness
3. **Version Distribution**: Track which versions users see
4. **Acceptance Rates**: Monitor acceptance by version
5. **Load Times**: Track Terms loading performance

## Rollback Plan

If server-driven Terms cause issues:

1. **Feature Flag**: Disable server fetch, use bundled only
2. **Server Rollback**: Revert to previous Terms version
3. **Client Update**: Release app update with fixed bundled Terms

## Future Enhancements

1. **A/B Testing**: Test different wordings
2. **Regional Variations**: Different Terms per country
3. **Rich Formatting**: Support HTML/rich text
4. **Change Highlights**: Show what changed between versions
5. **Acceptance Analytics**: Dashboard for acceptance metrics

## Implementation Timeline

- **Week 1**: Backend setup, Parse class creation
- **Week 2**: Client service implementation
- **Week 3**: ViewModel updates, testing
- **Week 4**: Caching, offline support
- **Week 5**: Testing, bug fixes
- **Week 6**: Gradual rollout

## Success Metrics

- ✅ 95%+ fetch success rate
- ✅ <500ms Terms load time (cached)
- ✅ <2s Terms load time (network)
- ✅ 100% offline fallback success
- ✅ Zero Terms-related crashes







