# Architecture Patterns Guide - FIN1

## Overview

This guide provides practical examples and patterns for implementing clean MVVM architecture in the FIN1 application. It serves as a reference for developers working on the codebase.

## 🏗️ Core Patterns

### 1. Service Protocol Pattern

**Purpose**: Define contracts for services to enable dependency injection and testing.

```swift
// ✅ CORRECT: Service protocol definition
protocol UserServiceProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }

    func signIn(email: String, password: String) async throws
    func signOut() async
    func refreshUserData() async throws
}

// ✅ CORRECT: Service implementation
class UserService: UserServiceProtocol {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    init() { } // Public initializer for DI

    func signIn(email: String, password: String) async throws {
        // Implementation
        self.isAuthenticated = true
        NotificationCenter.default.post(name: .userDidSignIn, object: nil)
    }

    func signOut() async {
        self.isAuthenticated = false
        self.currentUser = nil
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    }
}
```

### 2. ViewModel Pattern

**Purpose**: Manage view state and business logic with proper dependency injection.

```swift
// ✅ CORRECT: ViewModel with injected dependencies
class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userService: any UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(userService: any UserServiceProtocol) {
        self.userService = userService
        setupObservers()
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await userService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func setupObservers() {
        // Setup any necessary observers
    }
}
```

### 3. View Pattern

**Purpose**: Display UI and handle user interactions with proper ViewModel instantiation.

```swift
// ✅ CORRECT: View with proper ViewModel instantiation
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: AuthenticationViewModel

    init() {
        self._viewModel = StateObject(wrappedValue: AuthenticationViewModel(
            userService: AppServices.live.userService
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // UI implementation
                TextField("Email", text: $viewModel.email)
                SecureField("Password", text: $viewModel.password)

                Button("Sign In") {
                    Task {
                        await viewModel.signIn()
                    }
                }
                .disabled(viewModel.isLoading)
            }
            .responsivePadding()
        }
    }
}
```

### 4. Navigation Pattern

**Purpose**: Handle navigation with proper ViewModel lifecycle management.

```swift
// ✅ CORRECT: Navigation with wrapper views
struct MainTabView: View {
    @State private var selectedItem: NavigationItem?

    var body: some View {
        NavigationStack {
            List(navigationItems) { item in
                NavigationLink(value: item) {
                    NavigationRowView(item: item)
                }
            }
            .navigationDestination(for: NavigationItem.self) { item in
                NavigationDestinationWrapper(item: item)
            }
        }
    }
}

// ✅ CORRECT: Wrapper view for proper ViewModel instantiation
struct NavigationDestinationWrapper: View {
    let item: NavigationItem
    @StateObject private var viewModel: DetailViewModel

    init(item: NavigationItem) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: DetailViewModel(item: item))
    }

    var body: some View {
        DetailView(viewModel: viewModel)
    }
}
```

## 🔧 Composition Root Pattern

**Purpose**: Centralize service instantiation and dependency management.

```swift
// ✅ CORRECT: Composition root in AppServices
struct AppServices {
    static let live = AppServices()

    // Core services
    let userService: any UserServiceProtocol
    let notificationService: any NotificationServiceProtocol
    let documentService: any DocumentServiceProtocol

    // Feature services
    let invoiceService: any InvoiceServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let traderDataService: any TraderDataServiceProtocol

    // System services
    let telemetryService: any TelemetryServiceProtocol
    let testModeService: any TestModeServiceProtocol

    private init() {
        // Create core service instances (no singletons)
        self.userService = UserService()
        self.notificationService = NotificationService()
        self.documentService = DocumentService()

        // Create feature services
        self.invoiceService = InvoiceService()
        self.investmentService = InvestmentService()
        self.traderDataService = TraderDataService()

        // Create system services
        self.telemetryService = TelemetryService()
        self.testModeService = TestModeService()
    }
}

// ✅ CORRECT: Environment injection
extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.live
}
```

## 🎯 Common Patterns

### 1. Service with Multiple Dependencies

```swift
// ✅ CORRECT: Service with injected dependencies
class InvoiceService: InvoiceServiceProtocol {
    private let notificationService: any NotificationServiceProtocol
    private let documentService: any DocumentServiceProtocol

    init(notificationService: any NotificationServiceProtocol,
         documentService: any DocumentServiceProtocol) {
        self.notificationService = notificationService
        self.documentService = documentService
    }

    func createInvoice(_ invoice: Invoice) async throws {
        // Business logic
        try await documentService.saveInvoice(invoice)
        await notificationService.createNotification(
            title: "Invoice Created",
            message: "Invoice \(invoice.id) has been created"
        )
    }
}
```

### 2. ViewModel with Multiple Services

```swift
// ✅ CORRECT: ViewModel with multiple service dependencies
class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var isLoading = false

    private let invoiceService: any InvoiceServiceProtocol
    private let notificationService: any NotificationServiceProtocol

    init(invoiceService: any InvoiceServiceProtocol,
         notificationService: any NotificationServiceProtocol) {
        self.invoiceService = invoiceService
        self.notificationService = notificationService
    }

    func loadInvoices() async {
        isLoading = true
        do {
            invoices = try await invoiceService.getInvoices()
        } catch {
            // Handle error
        }
        isLoading = false
    }
}
```

### 3. Error Handling Pattern

```swift
// ✅ CORRECT: Centralized error handling
enum AppError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case validationError(String)
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serviceError(let message):
            return "Service error: \(message)"
        }
    }
}

// ✅ CORRECT: Service error handling
class UserService: UserServiceProtocol {
    func signIn(email: String, password: String) async throws {
        guard !email.isEmpty else {
            throw AppError.validationError("Email is required")
        }

        guard !password.isEmpty else {
            throw AppError.validationError("Password is required")
        }

        do {
            // Network call
            let result = try await networkService.signIn(email: email, password: password)
            self.isAuthenticated = true
            self.currentUser = result.user
        } catch {
            throw AppError.authenticationError("Invalid credentials")
        }
    }
}
```

## 🚫 Anti-Patterns to Avoid

### 1. Singleton Anti-Pattern

```swift
// ❌ WRONG: Singleton pattern
class UserService: ObservableObject {
    static let shared = UserService()

    private init() { } // Prevents proper DI

    func signIn() { }
}

// ❌ WRONG: Using singleton in ViewModel
class AuthenticationViewModel: ObservableObject {
    private let userService = UserService.shared // Hard to test
}
```

### 2. ViewModel Creation Anti-Pattern

```swift
// ❌ WRONG: ViewModel creation in view body
struct LoginView: View {
    @StateObject private var viewModel = AuthenticationViewModel() // Breaks observation
}
```

### 3. Direct Service Access Anti-Pattern

```swift
// ❌ WRONG: Direct service access in views
struct SomeView: View {
    var body: some View {
        Button("Action") {
            AppServices.live.userService.signIn() // Bypasses DI
        }
    }
}
```

## 🧪 Testing Patterns

### 1. Mock Service Pattern

```swift
// ✅ CORRECT: Mock service for testing
class MockUserService: UserServiceProtocol {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    var signInCallCount = 0
    var signInEmail: String?
    var signInPassword: String?

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        signInEmail = email
        signInPassword = password

        if email == "test@example.com" && password == "password" {
            isAuthenticated = true
            currentUser = User(id: "1", email: email)
        } else {
            throw AppError.authenticationError("Invalid credentials")
        }
    }

    func signOut() async {
        isAuthenticated = false
        currentUser = nil
    }
}
```

### 2. ViewModel Testing Pattern

```swift
// ✅ CORRECT: ViewModel testing with mock services
class AuthenticationViewModelTests: XCTestCase {
    var viewModel: AuthenticationViewModel!
    var mockUserService: MockUserService!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        viewModel = AuthenticationViewModel(userService: mockUserService)
    }

    func testSignInSuccess() async {
        // Given
        viewModel.email = "test@example.com"
        viewModel.password = "password"

        // When
        await viewModel.signIn()

        // Then
        XCTAssertTrue(mockUserService.isAuthenticated)
        XCTAssertEqual(mockUserService.signInCallCount, 1)
        XCTAssertEqual(mockUserService.signInEmail, "test@example.com")
    }
}
```

## 📋 Checklist for New Features

When implementing new features, follow this checklist:

### Service Implementation
- [ ] Create service protocol
- [ ] Implement service with public initializer
- [ ] Add to AppServices composition root
- [ ] Implement proper error handling
- [ ] Add notification posting for state changes

### ViewModel Implementation
- [ ] Inject required services via constructor
- [ ] Use `@Published` properties for UI state
- [ ] Implement proper async/await patterns
- [ ] Handle errors gracefully
- [ ] Add proper lifecycle management

### View Implementation
- [ ] Create ViewModel in `init()` method
- [ ] Use `@StateObject` for owned ViewModels
- [ ] Use `@ObservedObject` for injected ViewModels
- [ ] Use `@Environment(\.appServices)` for service access
- [ ] Implement proper navigation patterns

### Testing
- [ ] Create mock services for testing
- [ ] Write unit tests for ViewModels
- [ ] Test error scenarios
- [ ] Verify proper service interactions

## 🎯 Best Practices Summary

1. **Always use protocols** for service dependencies
2. **Inject dependencies** through constructors, not singletons
3. **Create ViewModels in init()** methods, not in view body
4. **Use composition root** for service instantiation
5. **Handle errors consistently** with AppError enum
6. **Post notifications** for important state changes
7. **Write tests** with mock services
8. **Follow naming conventions** for protocols and implementations
9. **Use async/await** instead of completion handlers
10. **Keep services stateless** and thread-safe

This guide provides the foundation for maintaining clean, testable, and maintainable code in the FIN1 application.
