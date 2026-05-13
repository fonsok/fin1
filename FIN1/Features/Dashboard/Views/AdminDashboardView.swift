import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.appServices) private var services
    @Environment(\.themeManager) private var themeManager
    @State private var showingAppSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    self.adminHeaderSection
                    self.webPortalBannerSection
                    self.systemInfoSection
                    MirrorBasisDriftHealthSection(apiClient: self.services.parseAPIClient)
                    self.appSettingsSection
                    self.appLedgerSection
                    self.userImpersonationSection
                    self.roleTestingSection
                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Admin")
            .sheet(isPresented: self.$showingAppSettings) {
                AdminAppSettingsView()
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

            Text("System information and development tools. Configuration, reports, and operations are managed via the Admin Web Portal.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Web Portal Banner
    private var webPortalBannerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "globe")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.4))
                    .foregroundColor(AppTheme.accentLightBlue)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Admin Web Portal")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                    Text("Konfiguration, Finanzen, Reports, Bank Contra Ledger, Freigaben und System-Status sind im Web Portal verfügbar.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                self.webPortalFeatureRow(icon: "slider.horizontal.3", title: "Konfiguration", subtitle: "4-Augen-Prinzip")
                self.webPortalFeatureRow(icon: "chart.bar.doc.horizontal", title: "Summary Report", subtitle: "Investments & Trades")
                self.webPortalFeatureRow(icon: "building.columns", title: "Bank Contra Ledger", subtitle: "Verrechnungskonten")
                self.webPortalFeatureRow(icon: "eurosign.circle", title: "Finanzen", subtitle: "Rundungsdifferenzen & Korrekturen")
                self.webPortalFeatureRow(icon: "checkmark.shield", title: "Freigaben", subtitle: "4-Augen-Workflow")
                self.webPortalFeatureRow(icon: "server.rack", title: "System-Status", subtitle: "Health Checks")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .fill(AppTheme.accentLightBlue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func webPortalFeatureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: 20)
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
            Text("–")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
            Text(subtitle)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            Spacer()
        }
    }

    // MARK: - System Info Section
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("System Information")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(6)) {
                AdminInfoRow(title: "Current Theme", value: self.themeManager.currentTargetGroup.displayName)
                AdminInfoRow(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                AdminInfoRow(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                AdminInfoRow(title: "User Role", value: self.services.userService.userRole?.displayName ?? "Unknown")
                AdminInfoRow(
                    title: "Commission Rate",
                    value: "\((self.services.configurationService.traderCommissionRate * 100).formatted(.number.precision(.fractionLength(0...2))))%"
                )
                AdminInfoRow(
                    title: "Initial Balance",
                    value: self.services.configurationService.initialAccountBalance.formatted(.currency(code: "EUR"))
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - App Settings Section (iOS-specific)
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("App Configuration")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Button(action: { self.showingAppSettings = true }, label: {
                AdminActionCard(
                    icon: "gear",
                    title: "App Settings",
                    subtitle: "Themes, target groups, and app configuration",
                    color: AppTheme.accentLightBlue
                )
            })
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - App Ledger & Beleg-Suche (buchhaltungsnahe Sicht)
    private var appLedgerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Buchhaltung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text(
                "Eigenkonten-Buchungen und Belege (Rechnungen, Gutschriften, Eigenbelege …) — Belege sind an der jeweiligen Buchung verlinkt."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))

            NavigationLink {
                AppLedgerView(viewModel: AppLedgerViewModel(ledgerService: self.services.appLedgerService))
            } label: {
                AdminActionCard(
                    icon: "books.vertical.fill",
                    title: "App Ledger öffnen",
                    subtitle: "Buchungen filtern · Belege an der Buchung",
                    color: AppTheme.accentOrange
                )
            }
            .buttonStyle(.plain)

            if let parseAPIClient = services.parseAPIClient {
                NavigationLink {
                    DocumentSearchView(searchService: DocumentSearchAPIService(parseAPIClient: parseAPIClient))
                } label: {
                    AdminActionCard(
                        icon: "doc.text.magnifyingglass",
                        title: "Beleg-Suche",
                        subtitle: "Belegnummer, Typ, Zeitraum, Investment/Trade",
                        color: AppTheme.accentLightBlue
                    )
                }
                .buttonStyle(.plain)
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

                if self.services.userService.isImpersonating {
                    Button(action: {
                        Task {
                            await self.services.userService.stopImpersonating()
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

            if self.services.userService.isImpersonating {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(AppTheme.accentOrange)
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                        Text("Impersonating: \(self.services.userService.currentUser?.displayName ?? "Unknown")")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)
                        Text("Role: \(self.services.userService.userRole?.displayName ?? "Unknown")")
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
                RoleTestButton(role: .investor, color: AppTheme.accentLightBlue, services: self.services)
                RoleTestButton(role: .trader, color: AppTheme.accentGreen, services: self.services)
                RoleTestButton(role: .customerService, color: AppTheme.accentOrange, services: self.services)
                RoleTestButton(role: .admin, color: AppTheme.accentRed, services: self.services)
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
            Image(systemName: self.icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(self.subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(ResponsiveDesign.captionFont())
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
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(self.value)
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
        Button(action: { self.switchToRole(self.role) }, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.role.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Switch to \(self.role.displayName)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Test \(self.role.displayName.lowercased()) interface")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.color)
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
            await self.services.userService.switchUserRole(to: newRole)
        }
    }
}

#Preview {
    AdminDashboardView()
        .environment(\.appServices, .live)
}
