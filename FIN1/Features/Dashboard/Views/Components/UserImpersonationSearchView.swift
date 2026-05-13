import SwiftUI

// MARK: - User Impersonation Search View
struct UserImpersonationSearchView: View {
    @Environment(\.appServices) private var services
    @StateObject private var viewModel: UserImpersonationViewModel

    init() {
        // Create placeholder ViewModel with live services; will be reconfigured with environment services
        let placeholderServices = AppServices.live
        _viewModel = StateObject(wrappedValue: UserImpersonationViewModel(
            customerSupportService: placeholderServices.customerSupportService,
            userService: placeholderServices.userService
        ))
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Search Bar (matching CSR Kundensuche style)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                TextField("Name, E-Mail oder Kundennummer...", text: self.$viewModel.searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .onSubmit {
                        self.viewModel.performSearch()
                    }

                if self.viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !self.viewModel.searchQuery.isEmpty {
                    Button(action: {
                        self.viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            // Search Results
            if self.viewModel.isLoading && self.viewModel.searchResults.isEmpty {
                ProgressView()
                    .padding()
            } else if self.viewModel.showError, let error = viewModel.errorMessage {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                    .padding()
            } else if !self.viewModel.searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(self.viewModel.searchResults) { result in
                            UserSearchResultRow(result: result) {
                                Task {
                                    await self.viewModel.impersonateUser(result)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else if !self.viewModel.searchQuery.isEmpty && !self.viewModel.isLoading {
                Text("No users found")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding()
            }
        }
        .task {
            // Reconfigure ViewModel with environment services
            self.viewModel.reconfigure(with: self.services)
        }
    }
}

// MARK: - User Search Result Row
struct UserSearchResultRow: View {
    let result: CustomerSearchResult
    let onImpersonate: () -> Void

    var body: some View {
        Button(action: self.onImpersonate) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Role Icon
                Image(systemName: self.roleIcon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.roleColor)
                    .frame(width: 30)

                // User Info
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.result.fullName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.result.email)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        Text("Kundennummer: \(self.result.customerNumber)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.tertiaryText)

                        Text("•")
                            .foregroundColor(AppTheme.tertiaryText)

                        Text(self.result.role.capitalized)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(self.roleColor)
                    }
                }

                Spacer()

                // Impersonate Button
                Image(systemName: "person.badge.key.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var roleIcon: String {
        switch self.result.role.lowercased() {
        case "investor": return "chart.pie.fill"
        case "trader": return "chart.bar.fill"
        case "admin": return "shield.lefthalf.filled"
        case "customerservice", "csr", "kundenberater": return "headphones.circle.fill"
        default: return "person.fill"
        }
    }

    private var roleColor: Color {
        switch self.result.role.lowercased() {
        case "investor": return AppTheme.accentLightBlue
        case "trader": return AppTheme.accentGreen
        case "admin": return AppTheme.accentRed
        case "customerservice", "csr", "kundenberater": return AppTheme.accentOrange
        default: return AppTheme.fontColor
        }
    }
}

#Preview {
    UserImpersonationSearchView()
        .environment(\.appServices, .live)
}
