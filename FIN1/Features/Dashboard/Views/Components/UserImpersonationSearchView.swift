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

                TextField("Name, E-Mail oder Kundennummer...", text: $viewModel.searchQuery)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .onSubmit {
                        viewModel.performSearch()
                    }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
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
            if viewModel.isLoading && viewModel.searchResults.isEmpty {
                ProgressView()
                    .padding()
            } else if viewModel.showError, let error = viewModel.errorMessage {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                    .padding()
            } else if !viewModel.searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(viewModel.searchResults) { result in
                            UserSearchResultRow(result: result) {
                                Task {
                                    await viewModel.impersonateUser(result)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else if !viewModel.searchQuery.isEmpty && !viewModel.isLoading {
                Text("No users found")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding()
            }
        }
        .task {
            // Reconfigure ViewModel with environment services
            viewModel.reconfigure(with: services)
        }
    }
}

// MARK: - User Search Result Row
struct UserSearchResultRow: View {
    let result: CustomerSearchResult
    let onImpersonate: () -> Void

    var body: some View {
        Button(action: onImpersonate) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Role Icon
                Image(systemName: roleIcon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(roleColor)
                    .frame(width: 30)

                // User Info
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(result.fullName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(result.email)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        Text("ID: \(result.customerId)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.tertiaryText)

                        Text("•")
                            .foregroundColor(AppTheme.tertiaryText)

                        Text(result.role.capitalized)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(roleColor)
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
        switch result.role.lowercased() {
        case "investor": return "chart.pie.fill"
        case "trader": return "chart.bar.fill"
        case "admin": return "shield.lefthalf.filled"
        case "customerservice", "csr", "kundenberater": return "headphones.circle.fill"
        default: return "person.fill"
        }
    }

    private var roleColor: Color {
        switch result.role.lowercased() {
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
