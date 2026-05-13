import SwiftUI

// MARK: - KYC Status List View
/// View showing all customers with their KYC status for easy overview
/// Helps CSRs identify customers who need KYC attention

struct KYCStatusListView: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var filterOption: KYCStatusFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.headerSection
                    self.filterSection
                    self.customersList
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("KYC-Status Übersicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        self.viewModel.closeKYCStatusList()
                        self.dismiss()
                    }
                }
            }
            .task {
                await self.viewModel.loadKYCStatusList()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentGreen)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("KYC-Status Übersicht")
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Übersicht aller Kunden mit KYC-Status")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()
            }

            // Statistics
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                StatisticCard(
                    title: "Gesamt",
                    value: "\(self.filteredCustomers.count)",
                    color: AppTheme.accentLightBlue
                )
                StatisticCard(
                    title: "Vollständig",
                    value: "\(self.completedCount)",
                    color: AppTheme.accentGreen
                )
                StatisticCard(
                    title: "Ausstehend",
                    value: "\(self.pendingCount)",
                    color: AppTheme.accentOrange
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Filter")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(KYCStatusFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.displayName,
                            isSelected: self.filterOption == filter,
                            color: filter.color
                        ) {
                            self.filterOption = filter
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Customers List

    private var customersList: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kunden (\(self.filteredCustomers.count))")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if self.filteredCustomers.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(ResponsiveDesign.largeTitleFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))

                    Text("Keine Kunden gefunden")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(20))
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.filteredCustomers) { customer in
                        KYCStatusCustomerRow(customer: customer) {
                            Task {
                                await self.viewModel.selectCustomer(customer)
                                self.viewModel.closeKYCStatusList()
                                self.dismiss()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Computed Properties

    private var filteredCustomers: [CustomerSearchResult] {
        switch self.filterOption {
        case .all:
            return self.viewModel.kycStatusList
        case .completed:
            return self.viewModel.kycStatusList.filter { $0.isKYCCompleted }
        case .pending:
            return self.viewModel.kycStatusList.filter { !$0.isKYCCompleted }
        }
    }

    private var completedCount: Int {
        self.viewModel.kycStatusList.filter { $0.isKYCCompleted }.count
    }

    private var pendingCount: Int {
        self.viewModel.kycStatusList.filter { !$0.isKYCCompleted }.count
    }
}

// MARK: - KYC Status Filter

enum KYCStatusFilter: CaseIterable {
    case all
    case completed
    case pending

    var displayName: String {
        switch self {
        case .all: return "Alle"
        case .completed: return "Vollständig"
        case .pending: return "Ausstehend"
        }
    }

    var color: Color {
        switch self {
        case .all: return AppTheme.accentLightBlue
        case .completed: return AppTheme.accentGreen
        case .pending: return AppTheme.accentOrange
        }
    }
}

// MARK: - Helper Views

struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text(self.value)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(self.color)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(self.isSelected ? AppTheme.screenBackground : self.color)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(self.isSelected ? self.color : self.color.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

struct KYCStatusCustomerRow: View {
    let customer: CustomerSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: self.onSelect) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Circle()
                    .fill(AppTheme.accentLightBlue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(self.customer.fullName.prefix(2).uppercased())
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentLightBlue)
                    )

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.customer.fullName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.customer.email)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        CSStatusBadge(
                            text: self.customer.isKYCCompleted ? "KYC Vollständig" : "KYC Ausstehend",
                            color: self.customer.isKYCCompleted ? AppTheme.accentGreen : AppTheme.accentOrange
                        )
                        CSStatusBadge(
                            text: self.customer.role.capitalized,
                            color: AppTheme.accentLightBlue
                        )
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    CustomerSupportDashboardView()
        .environment(\.appServices, .live)
}

