import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.appServices) private var services
    @Environment(\.themeManager) private var themeManager
    @StateObject private var roundingVM: RoundingDifferencesViewModel
    @State private var showingAppSettings = false
    @State private var showingFinancialSettings = false

    init() {
        // Use a lightweight init; actual services are resolved from environment in body
        _roundingVM = StateObject(wrappedValue: RoundingDifferencesViewModel(
            roundingService: RoundingDifferencesService(telemetryService: TelemetryService()),
            telemetryService: TelemetryService()
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    // Admin Header
                    adminHeaderSection

                    // App Configuration Section
                    appConfigurationSection

                    // Operations Section
                    operationsSection

                    // System Information Section
                    systemInfoSection

                    // User Impersonation Section
                    userImpersonationSection

                    // Role Testing Section (for development)
                    roleTestingSection

                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Admin")
            .task { await roundingVM.load() }
            .sheet(isPresented: $showingAppSettings) {
                AdminAppSettingsView()
            }
            .sheet(isPresented: $showingFinancialSettings) {
                AdminFinancialSettingsView()
            }
        }
    }

    // MARK: - Admin Header Section
    private var adminHeaderSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Administrative Controls")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Manage platform settings, configurations, and system parameters.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - App Configuration Section
    private var appConfigurationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("App Configuration")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(10)) {
                // App Settings
                Button(action: { showingAppSettings = true }, label: {
                    AdminActionCard(
                        icon: "gear",
                        title: "App Settings",
                        subtitle: "Themes, target groups, and app configuration",
                        color: AppTheme.accentLightBlue
                    )
                })

                // Financial Settings
                Button(action: { showingFinancialSettings = true }, label: {
                    AdminActionCard(
                        icon: "dollarsign.circle",
                        title: "Financial Settings",
                        subtitle: "Fees, tax rates, and investment limits",
                        color: AppTheme.accentGreen
                    )
                })

                // Configuration Management
                NavigationLink(destination: ConfigurationManagementView()) {
                    AdminActionCard(
                        icon: "slider.horizontal.3",
                        title: "System Configuration",
                        subtitle: "Cash reserves, commission rates, and balance settings",
                        color: AppTheme.accentOrange
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Operations Section
    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Operations")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(10)) {
                // Rounding Differences
                NavigationLink(destination: RoundingDifferencesAdminView(viewModel: roundingVM)) {
                    AdminActionCard(
                        icon: "plusminus.circle",
                        title: "Rounding Differences",
                        subtitle: "Review and manage calculation discrepancies",
                        color: AppTheme.accentOrange
                    )
                }

                // Bank Contra Ledger
                NavigationLink(destination: BankContraLedgerView(
                    viewModel: BankContraLedgerViewModel(
                        postingService: BankContraAccountPostingService()
                    )
                )) {
                    AdminActionCard(
                        icon: "building.columns",
                        title: "Bank Contra Ledger",
                        subtitle: "Bank account reconciliation and postings",
                        color: AppTheme.accentLightBlue
                    )
                }

                // Summary Report
                NavigationLink(destination: AdminSummaryReportView(services: services)) {
                    AdminActionCard(
                        icon: "chart.bar.doc.horizontal",
                        title: "Summary Report",
                        subtitle: "Completed investments and trades overview",
                        color: AppTheme.accentGreen
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - System Info Section
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("System Information")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(6)) {
                AdminInfoRow(title: "Current Theme", value: themeManager.currentTargetGroup.displayName)
                AdminInfoRow(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                AdminInfoRow(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                AdminInfoRow(title: "User Role", value: services.userService.userRole?.displayName ?? "Unknown")
                AdminInfoRow(title: "Commission Rate", value: "\(Int(services.configurationService.traderCommissionRate * 100))%")
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - User Impersonation Section
    private var userImpersonationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("User Impersonation")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                // Stop Impersonation Button (if impersonating)
                if services.userService.isImpersonating {
                    Button(action: {
                        Task {
                            await services.userService.stopImpersonating()
                        }
                    }) {
                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Return to Admin")
                        }
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentRed.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                    }
                }
            }

            if services.userService.isImpersonating {
                // Impersonation Indicator
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(AppTheme.accentOrange)
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                        Text("Impersonating: \(services.userService.currentUser?.displayName ?? "Unknown")")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                        Text("Role: \(services.userService.userRole?.displayName ?? "Unknown")")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding()
                .background(AppTheme.accentOrange.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            } else {
                Text("Search for a user to impersonate and test their experience.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                UserImpersonationSearchView()
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Role Testing Section
    private var roleTestingSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Role Testing")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Quick switch between user roles for testing purposes.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(10)) {
                RoleTestButton(role: .investor, color: AppTheme.accentLightBlue, services: services)
                RoleTestButton(role: .trader, color: AppTheme.accentGreen, services: services)
                RoleTestButton(role: .customerService, color: AppTheme.accentOrange, services: services)
                RoleTestButton(role: .admin, color: AppTheme.accentRed, services: services)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Admin Action Card
struct AdminActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Admin Info Row
struct AdminInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(value)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }
}

// MARK: - Role Test Button
struct RoleTestButton: View {
    let role: UserRole
    let color: Color
    let services: AppServices

    var body: some View {
        Button(action: { switchToRole(role) }, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: role.icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Switch to \(role.displayName)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Test \(role.displayName.lowercased()) interface")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
            )
        })
        .buttonStyle(PlainButtonStyle())
    }

    private func switchToRole(_ newRole: UserRole) {
        Task {
            await services.userService.switchUserRole(to: newRole)
        }
    }
}

#Preview {
    AdminDashboardView()
        .environment(\.appServices, .live)
}
