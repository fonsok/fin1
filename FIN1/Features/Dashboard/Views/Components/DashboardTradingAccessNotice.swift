import SwiftUI

/// Explains why dashboard trading/investment actions are unavailable for RC 1–4 users.
struct DashboardTradingAccessNotice: View {
    enum RoleContext {
        case investor
        case trader
    }

    let riskClass: RiskClass
    let roleContext: RoleContext

    private var message: String {
        switch self.roleContext {
        case .investor:
            return
                "Mit \(self.riskClass.displayName) ist eine neue Investition über FIN1 nicht möglich. Für Ihr Risikoprofil empfehlen wir eine klassische Vermögensverwaltung oder Investmentfonds."
        case .trader:
            return
                "Mit \(self.riskClass.displayName) ist der Handel mit Hebelprodukten über FIN1 nicht möglich. Für Ihr Risikoprofil empfehlen wir eine klassische Vermögensverwaltung oder Investmentfonds."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.accentOrange)
                .font(ResponsiveDesign.headlineFont())

            Text(self.message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.85))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityIdentifier("DashboardTradingAccessNotice")
    }
}

#Preview {
    DashboardTradingAccessNotice(riskClass: .riskClass2, roleContext: .investor)
        .padding()
        .background(AppTheme.screenBackground)
}
