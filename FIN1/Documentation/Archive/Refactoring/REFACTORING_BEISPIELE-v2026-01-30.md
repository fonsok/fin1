# Refactoring-Beispiele für FIN1

## Beispiel 1: TradesOverviewViewModel aufteilen

### Vorher (481 Zeilen)

```swift
// FIN1/Features/Trader/ViewModels/TradesOverviewViewModel.swift
@MainActor
final class TradesOverviewViewModel: ObservableObject {
    @Published var ongoingTrades: [TradeOverviewItem] = []
    @Published var completedTrades: [TradeOverviewItem] = []
    @Published var filteredOngoingTrades: [TradeOverviewItem] = []
    @Published var filteredCompletedTrades: [TradeOverviewItem] = []
    @Published var hasMoreTrades = true
    @Published var isLoading = false
    @Published var isCalculatingCommission = false
    @Published var columnWidths: ColumnWidths?
    @Published var showDepot: Bool = false
    @Published var selectedTrade: TradeOverviewItem?
    @Published var showTradeDetails: Bool = false
    @Published var hasActiveTrade: Bool = false
    @Published var errorMessage: String?
    @Published var showError = false

    // 9 verschiedene Services als optionale Properties
    private var orderService: (any OrderManagementServiceProtocol)?
    private var tradeService: (any TradeLifecycleServiceProtocol)?
    // ... weitere Services

    // 200+ Zeilen Filter-Logik
    func filterTrades(...) { /* komplexe Filter-Logik */ }

    // 150+ Zeilen Commission-Berechnung
    func calculateCommission(...) async throws { /* komplexe Berechnung */ }

    // 100+ Zeilen Trade-Loading-Logik
    func loadTrades(...) async { /* komplexe Loading-Logik */ }
}
```

### Nachher (Aufgeteilt in 3 Dateien)

```swift
// FIN1/Features/Trader/ViewModels/TradesOverview/TradesOverviewViewModel.swift (~250 Zeilen)
@MainActor
final class TradesOverviewViewModel: ObservableObject {
    @Published var ongoingTrades: [TradeOverviewItem] = []
    @Published var completedTrades: [TradeOverviewItem] = []
    @Published var isLoading = false
    @Published var showDepot: Bool = false
    @Published var selectedTrade: TradeOverviewItem?
    @Published var showTradeDetails: Bool = false
    @Published var hasActiveTrade: Bool = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Delegierte ViewModels
    let filteringViewModel: TradesOverviewFilteringViewModel
    let commissionCalculator: TradesOverviewCommissionCalculator

    private let orderService: any OrderManagementServiceProtocol
    private let tradeService: any TradeLifecycleServiceProtocol

    init(
        orderService: any OrderManagementServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        filteringViewModel: TradesOverviewFilteringViewModel,
        commissionCalculator: TradesOverviewCommissionCalculator
    ) {
        self.orderService = orderService
        self.tradeService = tradeService
        self.filteringViewModel = filteringViewModel
        self.commissionCalculator = commissionCalculator
    }

    func loadTrades() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let trades = try await tradeService.getAllTrades()
            ongoingTrades = trades.filter { !$0.isCompleted }
            completedTrades = trades.filter { $0.isCompleted }

            // Delegiere Filterung
            await filteringViewModel.updateFilters(
                ongoing: ongoingTrades,
                completed: completedTrades
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// FIN1/Features/Trader/ViewModels/TradesOverview/TradesOverviewFilteringViewModel.swift (~150 Zeilen)
@MainActor
final class TradesOverviewFilteringViewModel: ObservableObject {
    @Published var filteredOngoingTrades: [TradeOverviewItem] = []
    @Published var filteredCompletedTrades: [TradeOverviewItem] = []
    @Published var searchQuery: String = ""
    @Published var sortOrder: SortOrder = .dateDescending

    func updateFilters(
        ongoing: [TradeOverviewItem],
        completed: [TradeOverviewItem]
    ) async {
        filteredOngoingTrades = applyFilters(to: ongoing)
        filteredCompletedTrades = applyFilters(to: completed)
    }

    private func applyFilters(to trades: [TradeOverviewItem]) -> [TradeOverviewItem] {
        var filtered = trades

        // Search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { trade in
                trade.securityName.localizedCaseInsensitiveContains(searchQuery) ||
                trade.wkn.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // Sort
        filtered.sort { sortOrder.compare($0, $1) }

        return filtered
    }
}

// FIN1/Features/Trader/ViewModels/TradesOverview/TradesOverviewCommissionCalculator.swift (~100 Zeilen)
final class TradesOverviewCommissionCalculator {
    private let commissionCalculationService: any CommissionCalculationServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol

    init(
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.commissionCalculationService = commissionCalculationService
        self.configurationService = configurationService
    }

    func calculateCommission(
        for trade: TradeOverviewItem
    ) async throws -> Decimal {
        let rate = configurationService.traderCommissionPercentage
        return try await commissionCalculationService.calculateCommission(
            for: trade,
            rate: rate
        )
    }

    func calculateTotalCommission(
        for trades: [TradeOverviewItem]
    ) async throws -> Decimal {
        var total: Decimal = 0
        for trade in trades {
            total += try await calculateCommission(for: trade)
        }
        return total
    }
}
```

**Vorteile:**
- ✅ Jede Datei unter 400 Zeilen
- ✅ Klare Verantwortlichkeiten (Single Responsibility Principle)
- ✅ Einfacher zu testen (isolierte Komponenten)
- ✅ Wiederverwendbar (CommissionCalculator kann auch woanders genutzt werden)

---

## Beispiel 2: EditProfileView aufteilen

### Vorher (430 Zeilen)

```swift
// FIN1/Shared/Components/Profile/Components/Modals/EditProfileView.swift
struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel

    var body: some View {
        Form {
            // Personal Info Section (150 Zeilen)
            Section {
                // Viele TextFields für Personal Info
            }

            // Address Section (100 Zeilen)
            Section {
                // Viele TextFields für Address
            }

            // Employment Section (80 Zeilen)
            Section {
                // Viele TextFields für Employment
            }

            // Save Button (50 Zeilen)
            Section {
                // Save Button mit Validierung
            }
        }
    }
}
```

### Nachher (Aufgeteilt in 4 Dateien)

```swift
// FIN1/Shared/Components/Profile/Components/Modals/EditProfileView.swift (~100 Zeilen)
struct EditProfileView: View {
    @StateObject private var viewModel: EditProfileViewModel

    var body: some View {
        Form {
            EditProfilePersonalInfoSection(viewModel: viewModel)
            EditProfileAddressSection(viewModel: viewModel)
            EditProfileEmploymentSection(viewModel: viewModel)
            EditProfileSaveSection(viewModel: viewModel)
        }
        .navigationTitle("Profil bearbeiten")
    }
}

// FIN1/Shared/Components/Profile/Components/Modals/Sections/EditProfilePersonalInfoSection.swift (~150 Zeilen)
struct EditProfilePersonalInfoSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section {
            if !viewModel.canEditPersonalInfo {
                Text("Persönliche Informationen können nicht bearbeitet werden")
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            Picker("Anrede", selection: $viewModel.salutation) {
                ForEach(Salutation.allCases, id: \.self) { salutation in
                    Text(salutation.displayName).tag(salutation)
                }
            }
            .disabled(!viewModel.canEditPersonalInfo)

            // Weitere Personal Info Fields...
        } header: {
            Text("Persönliche Informationen")
        }
    }
}

// FIN1/Shared/Components/Profile/Components/Modals/Sections/EditProfileAddressSection.swift (~100 Zeilen)
struct EditProfileAddressSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section {
            // Address Fields...
        } header: {
            Text("Adresse")
        }
    }
}

// FIN1/Shared/Components/Profile/Components/Modals/Sections/EditProfileEmploymentSection.swift (~80 Zeilen)
struct EditProfileEmploymentSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section {
            // Employment Fields...
        } header: {
            Text("Beschäftigung")
        }
    }
}

// FIN1/Shared/Components/Profile/Components/Modals/Sections/EditProfileSaveSection.swift (~50 Zeilen)
struct EditProfileSaveSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section {
            Button("Speichern") {
                Task {
                    await viewModel.save()
                }
            }
            .foregroundColor(
                viewModel.isFormValid && !viewModel.isLoading
                    ? AppTheme.screenBackground
                    : AppTheme.fontColor.opacity(0.5)
            )
            .background(
                viewModel.isFormValid && !viewModel.isLoading
                    ? AppTheme.accentLightBlue
                    : AppTheme.systemTertiaryBackground
            )
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
        }
    }
}
```

**Vorteile:**
- ✅ Jede Datei unter 300 Zeilen
- ✅ Wiederverwendbare Sections
- ✅ Einfacher zu testen (jede Section isoliert)
- ✅ Bessere Übersichtlichkeit

---

## Beispiel 3: Investment Model aufteilen

### Vorher (457 Zeilen)

```swift
// FIN1/Features/Investor/Models/Investment.swift
struct Investment {
    // 50 Properties
    let id: String
    let traderId: String
    // ... viele weitere Properties

    // 200 Zeilen Computed Properties
    var totalAmount: Decimal { /* ... */ }
    var currentValue: Decimal { /* ... */ }
    // ... viele weitere Computed Properties

    // 150 Zeilen Extensions
    // Investment+Calculations.swift
    // Investment+Formatting.swift
    // Investment+Validation.swift
}
```

### Nachher (Aufgeteilt in 3 Dateien)

```swift
// FIN1/Features/Investor/Models/Investment.swift (~150 Zeilen)
struct Investment: Identifiable, Codable {
    let id: String
    let traderId: String
    let amount: Decimal
    let createdAt: Date
    let updatedAt: Date
    // ... Kern-Properties (nur Datenstruktur)

    // Nur grundlegende Computed Properties
    var isActive: Bool {
        // Einfache Logik
    }
}

// FIN1/Features/Investor/Models/Investment+Calculations.swift (~150 Zeilen)
extension Investment {
    var totalAmount: Decimal {
        // Komplexe Berechnung
    }

    var currentValue: Decimal {
        // Komplexe Berechnung
    }

    var roi: Decimal {
        // Komplexe Berechnung
    }

    // Alle Berechnungs-Logik hier
}

// FIN1/Features/Investor/Models/Investment+Formatting.swift (~100 Zeilen)
extension Investment {
    var formattedAmount: String {
        // Formatierung
    }

    var formattedROI: String {
        // Formatierung
    }

    // Alle Formatierungs-Logik hier
}

// FIN1/Features/Investor/Models/Investment+Validation.swift (~50 Zeilen)
extension Investment {
    var isValid: Bool {
        // Validierung
    }

    func validate() throws {
        // Validierungs-Logik
    }
}
```

**Vorteile:**
- ✅ Kern-Model unter 200 Zeilen
- ✅ Klare Trennung: Datenstruktur vs. Berechnungen vs. Formatierung
- ✅ Einfacher zu testen (jede Extension isoliert)
- ✅ Bessere Wartbarkeit

---

## Beispiel 4: Services als `final` markieren

### Vorher

```swift
// FIN1/Features/Trader/Services/MarketPriceService.swift
class MarketPriceService {
    // Nicht final - kann vererbt werden (aber wird nicht)
}
```

### Nachher

```swift
// FIN1/Features/Trader/Services/MarketPriceService.swift
final class MarketPriceService {
    // Final - klar, dass keine Vererbung gewünscht ist
    // Performance: Static dispatch möglich
}
```

**Automatisierter Fix:**

```bash
#!/bin/bash
# scripts/mark-services-final.sh

# Finde alle Service-Dateien
find FIN1/Features -name "*Service.swift" -type f | while read file; do
    # Prüfe, ob bereits final ist
    if grep -q "^class " "$file" && ! grep -q "^final class " "$file"; then
        # Prüfe, ob es eine Base-Klasse ist (sollte nicht final sein)
        if ! grep -q "class.*BaseService\|class.*AbstractService" "$file"; then
            # Ersetze "class " mit "final class "
            sed -i '' 's/^class /final class /' "$file"
            echo "✅ Marked as final: $file"
        else
            echo "⏭️  Skipped (base class): $file"
        fi
    fi
done
```

---

## Beispiel 5: DRY-Verletzung beheben

### Vorher (Duplizierte Logik)

```swift
// FIN1/Features/Dashboard/Views/Components/DashboardTraderOverview.swift
struct DashboardTraderOverview: View {
    private func findTraderByID(_ id: String) -> MockTrader? {
        // Duplizierte Implementierung
        return traderDataService.getAllTraders().first { $0.id == id }
    }

    private func computeExpectancy(_ trader: MockTrader) -> Decimal {
        // Duplizierte Berechnung
        // ... komplexe Logik
    }
}

// FIN1/Features/Investor/Views/Components/HitlistTableSection.swift
struct HitlistTableSection: View {
    private func findTraderByID(_ id: String) -> MockTrader? {
        // Identische Implementierung (DUPLIKAT!)
        return traderDataService.getAllTraders().first { $0.id == id }
    }

    private func computeExpectancy(_ trader: MockTrader) -> Decimal {
        // Identische Berechnung (DUPLIKAT!)
        // ... komplexe Logik
    }
}
```

### Nachher (Zentralisiert)

```swift
// FIN1/Features/Trader/Services/TraderDataService.swift
extension TraderDataService {
    func getTrader(by id: String) -> MockTrader? {
        // Einmalige Implementierung
        return getAllTraders().first { $0.id == id }
    }
}

// FIN1/Features/Trader/Services/TradingStatisticsService.swift
final class TradingStatisticsService {
    private let traderDataService: any TraderDataServiceProtocol

    init(traderDataService: any TraderDataServiceProtocol) {
        self.traderDataService = traderDataService
    }

    func computeExpectancy(for trader: MockTrader) -> Decimal {
        // Einmalige Implementierung
        // ... komplexe Logik
    }
}

// FIN1/Features/Dashboard/Views/Components/DashboardTraderOverview.swift
struct DashboardTraderOverview: View {
    @Environment(\.appServices) private var appServices

    private func findTraderByID(_ id: String) -> MockTrader? {
        // Nutze Service-Methode
        return appServices.traderDataService.getTrader(by: id)
    }

    private func computeExpectancy(_ trader: MockTrader) -> Decimal {
        // Nutze Statistics-Service
        return appServices.tradingStatisticsService.computeExpectancy(for: trader)
    }
}

// FIN1/Features/Investor/Views/Components/HitlistTableSection.swift
struct HitlistTableSection: View {
    @Environment(\.appServices) private var appServices

    private func findTraderByID(_ id: String) -> MockTrader? {
        // Nutze Service-Methode (kein Duplikat mehr!)
        return appServices.traderDataService.getTrader(by: id)
    }

    private func computeExpectancy(_ trader: MockTrader) -> Decimal {
        // Nutze Statistics-Service (kein Duplikat mehr!)
        return appServices.tradingStatisticsService.computeExpectancy(for: trader)
    }
}
```

**Vorteile:**
- ✅ DRY-Prinzip befolgt
- ✅ Einmalige Implementierung = einfachere Wartung
- ✅ Testbar (Service-Methoden können isoliert getestet werden)
- ✅ Wiederverwendbar (andere Views können auch nutzen)

---

## Zusammenfassung der Refactoring-Patterns

1. **ViewModels aufteilen:** Extract Sub-ViewModels für spezifische Verantwortlichkeiten
2. **Views aufteilen:** Extract Sub-Views/Sections für UI-Komponenten
3. **Models aufteilen:** Extensions für Berechnungen, Formatierung, Validierung
4. **Services final markieren:** Automatisierter Fix für Performance
5. **DRY befolgen:** Zentralisierte Logik in Services statt Duplikate in Views

Diese Patterns können auf alle großen Dateien angewendet werden.





