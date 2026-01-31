import Danger

let danger = Danger()

// Fail PRs if they touch nested test folders or introduce singleton misuse in non-root code
if danger.git.createdFiles.contains(where: { $0.contains("FIN1/FIN1Tests/") }) ||
   danger.git.modifiedFiles.contains(where: { $0.contains("FIN1/FIN1Tests/") }) {
    fail("Do not add or modify tests in nested folder FIN1/FIN1Tests/. Use FIN1Tests/ at repo root.")
}

// Fail PRs if they add files to nested FIN1/FIN1 directory (common source of duplicate files)
if danger.git.createdFiles.contains(where: { $0.contains("FIN1/FIN1/Features/") }) {
    fail("Do not add files to FIN1/FIN1/Features/. This is a duplicate directory structure. Use FIN1/Features/ instead.")
}

// Warn if files are modified in nested FIN1/FIN1 directory
if danger.git.modifiedFiles.contains(where: { $0.contains("FIN1/FIN1/Features/") }) {
    warn("⚠️  Files in FIN1/FIN1/Features/ were modified. This directory structure may be a duplicate. Consider moving files to FIN1/Features/ instead.")
}

let changedSwiftFiles = (danger.git.createdFiles + danger.git.modifiedFiles).filter { $0.hasSuffix(".swift") }

// Simple grep-like checks for singleton usage and default singleton init in VMs
for file in changedSwiftFiles {
    if file.hasPrefix("FIN1/") && !file.contains("FIN1App.swift") {
        if let content = danger.utils.readFile(file) as String? {
            if content.contains("= UserService.shared") || content.contains("= NotificationService.shared") || content.contains("= DocumentService.shared") || content.contains("= WatchlistService.shared") {
                fail("Avoid using .shared in non-root code. Inject via protocols. File: \(file)")
            }
            if file.contains("/ViewModels/") && content.contains("= UserService.shared") {
                fail("ViewModel init must not default to singletons. File: \(file)")
            }
        }
    }
}

// Require tests when ViewModels are changed
let vmTouched = changedSwiftFiles.contains { $0.contains("/ViewModels/") }
let testsTouched = (danger.git.createdFiles + danger.git.modifiedFiles).contains { $0.hasPrefix("FIN1Tests/") }
if vmTouched && !testsTouched {
    warn("ViewModel changed but no tests were touched. Consider adding/updating tests in FIN1Tests/.")
}

// CRITICAL: Protect ALL securities search filter logic from being broken again
let securitiesSearchFilterFiles = [
    "FIN1/Features/Trader/Services/MockDataGenerator.swift",
    "FIN1/Features/Trader/Models/SearchResult.swift",
    "FIN1/Features/Trader/Services/SecuritiesSearchService.swift",
    "FIN1/Features/Trader/Services/SearchFilterService.swift",
    "FIN1/Features/Trader/Services/SecuritiesSearchCoordinator.swift",
    "FIN1/Features/Trader/ViewModels/SecuritiesSearchViewModel.swift",
    "FIN1/Features/Trader/Views/SecuritiesSearchView.swift",
    "FIN1/Features/Trader/Components/Search/SearchFormSection.swift",
    "FIN1/Features/Trader/Components/Search/FilterSection.swift"
]

let securitiesSearchFilterTouched = changedSwiftFiles.contains { file in
    securitiesSearchFilterFiles.contains { $0.contains(file) }
}

if securitiesSearchFilterTouched {
    let securitiesSearchTestsTouched = (danger.git.createdFiles + danger.git.modifiedFiles).contains {
        $0.contains("SecuritiesSearchFilterTests.swift") || $0.contains("BasiswertFilterTests.swift")
    }

    if !securitiesSearchTestsTouched {
        fail("🚨 CRITICAL: Securities search filter logic was modified but SecuritiesSearchFilterTests.swift was not updated. This logic was previously broken and must be protected with tests.")
    }

    warn("⚠️  Securities search filter logic was modified. Please ensure:")
    warn("1. All SecuritiesSearchFilterTests pass")
    warn("2. All BasiswertFilterTests pass")
    warn("3. Manual testing shows correct filter behavior:")
    warn("   - Category filter works (Optionsschein, and any new categories)")
    warn("   - Basiswert filter works (all items from 'Basiswerte' card)")
    warn("   - Direction filter works (Call, Put)")
    warn("   - Strike Price Gap filter works (Am Geld, Aus dem Geld)")
    warn("   - Restlaufzeit filter works (< 4 Wo., > 1 Jahr)")
    warn("   - Emittent filter works (all items from 'Emittent' card)")
    warn("   - Omega filter works (> 10, < 5)")
    warn("4. No stale results persist when switching between filter selections")
    warn("5. Combined filters work correctly together")
    warn("6. Dynamic filter lists work correctly (new/removed items)")
    warn("7. System gracefully handles discontinued issuers/products")
}

// Separation of Concerns: Prevent Views in Models/ directory
let viewsInModels = changedSwiftFiles.filter { file in
    file.contains("/Models/") && file.contains("View") && !file.contains("Model")
}
if !viewsInModels.isEmpty {
    fail("🚨 Views found in Models/ directory. Views must be in Views/ directory, not Models/. Files: \(viewsInModels.joined(separator: ", "))")
}

// Separation of Concerns: Prevent ViewModels in Views/ directory
let viewModelsInViews = changedSwiftFiles.filter { file in
    file.contains("/Views/") && file.contains("ViewModel") && !file.contains("/ViewModels/")
}
if !viewModelsInViews.isEmpty {
    fail("🚨 ViewModels found in Views/ directory. ViewModels must be in ViewModels/ directory. Files: \(viewModelsInViews.joined(separator: ", "))")
}

// Separation of Concerns: Warn if Views contain direct service calls
for file in changedSwiftFiles {
    if file.contains("/Views/") && !file.contains("ViewModel") && !file.contains("Wrapper") {
        if let content = danger.utils.readFile(file) as String? {
            // Check for direct service access patterns
            if content.contains("services.") && !content.contains("@Environment") {
                warn("⚠️  View contains direct service access: \(file). Consider using ViewModel for service calls.")
            }
            // Check for business logic patterns
            if content.contains(".filter {") || content.contains(".map {") || content.contains(".reduce(") {
                warn("⚠️  View may contain business logic: \(file). Consider moving to ViewModel.")
            }
        }
    }
}

// File Size: Warn if files exceed 400 lines
for file in changedSwiftFiles {
    if let content = danger.utils.readFile(file) as String? {
        let lines = content.components(separatedBy: .newlines).count
        if lines > 400 {
            warn("⚠️  Large file detected: \(file) has \(lines) lines (limit: 400). Consider splitting into smaller files or extracting to extensions.")
        }
    }
}

// Basic PR hygiene
if let body = danger.github?.pullRequest.body, body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    warn("Please add a brief PR description.")
}



