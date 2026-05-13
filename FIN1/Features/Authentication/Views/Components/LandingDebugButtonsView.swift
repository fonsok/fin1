import SwiftUI

/// Debug buttons for test user login (only visible in DEBUG builds)
struct LandingDebugButtonsView: View {
    @ObservedObject var viewModel: LandingViewModel

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            // Test Investors
            TestUserSection(
                title: "Test Investors",
                count: 5,
                style: self.viewModel.designStyle,
                isLoading: self.viewModel.isLoading,
                action: { number in
                    Task {
                        await self.viewModel.signInAsInvestor(number: number)
                    }
                },
                buttonText: { number in
                    "Investor \(number) – \(TestConstants.investorDisplayName(for: number))"
                },
                accessibilityPrefix: "LoginInvestor",
                accentColor: AppTheme.accentLightBlue
            )

            // Test Traders
            TestUserSection(
                title: "Test Traders",
                count: 5,
                style: self.viewModel.designStyle,
                isLoading: self.viewModel.isLoading,
                action: { number in
                    Task {
                        await self.viewModel.signInAsTrader(number: number)
                    }
                },
                buttonText: { number in
                    "Trader \(number) – \(TestConstants.traderDisplayName(for: number))"
                },
                accessibilityPrefix: "LoginTrader",
                accentColor: AppTheme.accentGreen
            )

            // Test Admin
            TestAdminSection(
                style: self.viewModel.designStyle,
                isLoading: self.viewModel.isLoading,
                action: {
                    Task {
                        await self.viewModel.signInAsAdmin()
                    }
                }
            )

            // Test CSR (mit 6 Rollen: L1, L2, Fraud, Compliance, Tech, Teamlead)
            TestCSRSection(
                style: self.viewModel.designStyle,
                isLoading: self.viewModel.isLoading,
                action: { number in
                    Task {
                        await self.viewModel.signInAsCSR(number: number)
                    }
                },
                roleAction: { role in
                    Task {
                        await self.viewModel.signInAsCSRWithRole(role)
                    }
                }
            )

            CompanyKybDebugSection(style: self.viewModel.designStyle)
        }
    }
}

// MARK: - Company KYB Debug Section

private struct CompanyKybDebugSection: View {
    let style: LandingViewModel.DesignStyle
    @State private var showKybWizard = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            Text("Company KYB (Mock)")
                .font(self.style == .typewriter
                    ? ResponsiveDesign.monospacedFont(size: 14, weight: .bold)
                    : ResponsiveDesign.captionFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { self.showKybWizard = true }) {
                if self.style == .typewriter {
                    HStack(spacing: ResponsiveDesign.spacing(6)) {
                        Image(systemName: "building.2")
                            .font(ResponsiveDesign.scaledSystemFont(size: 12))
                        Text("Company KYB Wizard (8 Steps)")
                            .font(ResponsiveDesign.monospacedFont(size: 12, weight: .regular))
                    }
                    .foregroundColor(Color("InputText"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: ResponsiveDesign.spacing(6)) {
                        Image(systemName: "building.2")
                            .font(ResponsiveDesign.captionFont())
                        Text("Company KYB Wizard (8 Steps)")
                            .font(ResponsiveDesign.captionFont())
                    }
                    .foregroundColor(.orange.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .accessibilityIdentifier("DebugCompanyKybButton")
            .fullScreenCover(isPresented: self.$showKybWizard) {
                CompanyKybView(companyKybAPIService: MockCompanyKybAPIService())
            }
        }
    }
}

// MARK: - Test User Section

private struct TestUserSection: View {
    let title: String
    let count: Int
    let style: LandingViewModel.DesignStyle
    let isLoading: Bool
    let action: (Int) -> Void
    let buttonText: (Int) -> String
    let accessibilityPrefix: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            Text(self.title)
                .font(self.style == .typewriter
                    ? ResponsiveDesign.monospacedFont(size: 14, weight: .bold)
                    : ResponsiveDesign.captionFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(1...self.count, id: \.self) { number in
                LandingDebugButton(
                    text: self.buttonText(number),
                    style: self.style,
                    accentColor: self.accentColor,
                    isLoading: self.isLoading,
                    action: { self.action(number) },
                    accessibilityIdentifier: "\(self.accessibilityPrefix)\(number)Button"
                )
            }
        }
    }
}

// MARK: - Test Admin Section

private struct TestAdminSection: View {
    let style: LandingViewModel.DesignStyle
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            Text("Test Admin")
                .font(self.style == .typewriter
                    ? ResponsiveDesign.monospacedFont(size: 14, weight: .bold)
                    : ResponsiveDesign.captionFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            LandingDebugButton(
                text: "Test: Sign In as Admin",
                style: self.style,
                accentColor: AppTheme.accentLightBlue,
                isLoading: self.isLoading,
                action: self.action,
                accessibilityIdentifier: "LoginAdminButton"
            )
        }
    }
}

// MARK: - Test CSR Section

private struct TestCSRSection: View {
    let style: LandingViewModel.DesignStyle
    let isLoading: Bool
    let action: (Int) -> Void
    var roleAction: ((CSRRole) -> Void)?

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            Text("Test CSR (Rollenbasiert)")
                .font(self.style == .typewriter
                    ? ResponsiveDesign.monospacedFont(size: 14, weight: .bold)
                    : ResponsiveDesign.captionFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if self.style == .typewriter {
                // Typewriter style - vertical list
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    self.csrRoleButton(role: .level1, color: AppTheme.accentLightBlue, icon: "1.circle.fill")
                    self.csrRoleButton(role: .level2, color: AppTheme.accentLightBlue, icon: "2.circle.fill")
                    self.csrRoleButton(role: .fraud, color: AppTheme.accentRed, icon: "exclamationmark.shield.fill")
                    self.csrRoleButton(role: .compliance, color: AppTheme.accentGreen, icon: "checkmark.shield.fill")
                    self.csrRoleButton(role: .techSupport, color: AppTheme.accentOrange, icon: "wrench.and.screwdriver.fill")
                    self.csrRoleButton(role: .teamlead, color: Color.purple, icon: "star.fill")
                }
            } else {
                // Original style - 2-column grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ResponsiveDesign.spacing(8)) {
                    self.csrRoleButton(role: .level1, color: AppTheme.accentLightBlue, icon: "1.circle.fill")
                    self.csrRoleButton(role: .level2, color: AppTheme.accentLightBlue, icon: "2.circle.fill")
                    self.csrRoleButton(role: .fraud, color: AppTheme.accentRed, icon: "exclamationmark.shield.fill")
                    self.csrRoleButton(role: .compliance, color: AppTheme.accentGreen, icon: "checkmark.shield.fill")
                    self.csrRoleButton(role: .techSupport, color: AppTheme.accentOrange, icon: "wrench.and.screwdriver.fill")
                    self.csrRoleButton(role: .teamlead, color: Color.purple, icon: "star.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func csrRoleButton(role: CSRRole, color: Color, icon: String) -> some View {
        CSRRoleDebugButton(
            role: role,
            color: color,
            icon: icon,
            style: self.style,
            isLoading: self.isLoading,
            action: { self.roleAction?(role) }
        )
    }
}

// MARK: - CSR Role Debug Button

private struct CSRRoleDebugButton: View {
    let role: CSRRole
    let color: Color
    let icon: String
    let style: LandingViewModel.DesignStyle
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            if self.style == .typewriter {
                HStack(spacing: ResponsiveDesign.spacing(6)) {
                    Image(systemName: self.icon)
                        .font(ResponsiveDesign.scaledSystemFont(size: 12))
                    Text(self.role.displayName)
                        .font(ResponsiveDesign.monospacedFont(size: 12, weight: .regular))
                }
                .foregroundColor(Color("InputText"))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: self.icon)
                        .font(ResponsiveDesign.scaledSystemFont(size: 10))
                    Text(self.role.rawValue)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                }
                .foregroundColor(self.color.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(self.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .stroke(self.color.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
        .accessibilityIdentifier("LoginCSR\(self.role.rawValue)Button")
        .disabled(self.isLoading)
    }
}

// MARK: - Landing Debug Button

struct LandingDebugButton: View {
    let text: String
    let style: LandingViewModel.DesignStyle
    let accentColor: Color
    let isLoading: Bool
    let action: () -> Void
    let accessibilityIdentifier: String

    var body: some View {
        Button(action: self.action, label: {
            if self.style == .typewriter {
                Text("  - \(self.text)")
                    .font(ResponsiveDesign.monospacedFont(size: 14, weight: .regular))
                    .foregroundColor(Color("InputText"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(self.text)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.accentColor.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                            .stroke(self.accentColor.opacity(0.3), lineWidth: 1)
                    )
            }
        })
        .accessibilityIdentifier(self.accessibilityIdentifier)
        .disabled(self.isLoading)
    }
}

