import SwiftUI

struct IndividualFiltersSection: View {
    let activeFilters: [IndividualFilterCriteria]
    let onAddFilter: (IndividualFilterCriteria) -> Void
    let onRemoveFilter: (IndividualFilterCriteria.FilterType) -> Void
    let onShowMoreFilters: () -> Void
    @State private var selectedTimeRange: FilterSuccessRateOption = .lastMonth
    @State private var selectedReturnOption: ReturnPercentageOption = .none
    @State private var selectedNumberOfTradesOption: NumberOfTradesOption = .none
    @State private var selectedSuccessRateOption: FilterSuccessRateOption = .none

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Individual Filters")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            // Time range (two rows, centered)
            LabeledDropdownRow(
                label: IndividualFilterCriteria.FilterType.timeRange.displayName,
                alignment: .center,
                selected: $selectedTimeRange,
                options: FilterSuccessRateOption.allCases.filter { $0.timePeriod != nil || $0 == .none },
                optionTitle: { $0.displayName }
            )
            .padding(.leading, ResponsiveDesign.horizontalPadding())
            .onChange(of: selectedTimeRange) { _, newValue in
                if newValue == .none {
                    onRemoveFilter(.timeRange)
                } else {
                    onAddFilter(IndividualFilterCriteria(type: .timeRange, successRateOption: newValue))
                }
            }

            // Individual filters (two rows each, leading)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Ø-Return per Trade
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.returnRate.displayName,
                    alignment: .leading,
                    selected: $selectedReturnOption,
                    options: ReturnPercentageOption.allCases,
                    optionTitle: { $0.displayName }
                )
                .onChange(of: selectedReturnOption) { _, newValue in
                    if newValue == .none {
                        onRemoveFilter(.returnRate)
                    } else {
                        onAddFilter(IndividualFilterCriteria(type: .returnRate, returnPercentageOption: newValue))
                    }
                }

                // Number of trades
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.numberOfTrades.displayName,
                    alignment: .leading,
                    selected: $selectedNumberOfTradesOption,
                    options: NumberOfTradesOption.allCases,
                    optionTitle: { $0.displayName }
                )
                .onChange(of: selectedNumberOfTradesOption) { _, newValue in
                    if newValue == .none {
                        onRemoveFilter(.numberOfTrades)
                    } else {
                        onAddFilter(IndividualFilterCriteria(type: .numberOfTrades, numberOfTradesOption: newValue))
                    }
                }

                // Recent successful trades
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.recentSuccessfulTrades.displayName,
                    alignment: .leading,
                    selected: $selectedSuccessRateOption,
                    options: FilterSuccessRateOption.allCases.filter { $0.timePeriod == nil },
                    optionTitle: { $0.displayName }
                )
                .onChange(of: selectedSuccessRateOption) { _, newValue in
                    if newValue == .none {
                        onRemoveFilter(.recentSuccessfulTrades)
                    } else {
                        onAddFilter(IndividualFilterCriteria(type: .recentSuccessfulTrades, successRateOption: newValue))
                    }
                }
            }
            .padding(.leading, ResponsiveDesign.horizontalPadding())

            // Show more filters link (leading)
            HStack {
                Button(action: {
                    onShowMoreFilters()
                }) {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: "pencil")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                        Text("show more filters")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.leading, ResponsiveDesign.horizontalPadding())
        }
        .padding(.vertical, ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .onChange(of: activeFilters) { _, _ in
            syncSelectedFromActiveFilters()
        }
        .task {
            syncSelectedFromActiveFilters()
        }
    }
}

// MARK: - Reusable Labeled Dropdown Row (two rows)
private struct LabeledDropdownRow<Option: Hashable>: View {
    enum RowAlignment { case leading, center }

    let label: String
    let alignment: RowAlignment
    @Binding var selected: Option
    let options: [Option]
    let optionTitle: (Option) -> String

    @State private var showDropdown = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text(label)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                if alignment == .center { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)

            HStack {
                Button(action: { showDropdown.toggle() }, label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(optionTitle(selected))
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.light)
                            .foregroundColor(AppTheme.fontColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(6))
                    .background(AppTheme.accentLightBlue.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                            .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                    )
                    .cornerRadius(ResponsiveDesign.spacing(6))
                })
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showDropdown) {
                    NavigationStack {
                        List(options, id: \.self) { option in
                            Button(action: {
                                selected = option
                                showDropdown = false
                            }) {
                                HStack {
                                    Text(optionTitle(option))
                                        .foregroundColor(AppTheme.fontColor)
                                    Spacer()
                                    if option == selected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppTheme.accentLightBlue)
                                    }
                                }
                            }
                        }
                        .navigationTitle(label)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showDropdown = false }
                                    .foregroundColor(AppTheme.accentLightBlue)
                            }
                        }
                    }
                }
                if alignment == .center { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        }
    }
}

// MARK: - Active filters sync
private extension IndividualFiltersSection {
    func syncSelectedFromActiveFilters() {
        if let time = activeFilters.first(where: { $0.type == .timeRange })?.successRateOption {
            selectedTimeRange = time
        } else {
            selectedTimeRange = .none
        }

        if let ret = activeFilters.first(where: { $0.type == .returnRate })?.returnPercentageOption {
            selectedReturnOption = ret
        } else {
            selectedReturnOption = .none
        }

        if let trades = activeFilters.first(where: { $0.type == .numberOfTrades })?.numberOfTradesOption {
            selectedNumberOfTradesOption = trades
        } else {
            selectedNumberOfTradesOption = .none
        }

        if let recent = activeFilters.first(where: { $0.type == .recentSuccessfulTrades })?.successRateOption {
            selectedSuccessRateOption = recent
        } else {
            selectedSuccessRateOption = .none
        }
    }
}

#Preview {
    IndividualFiltersSection(
        activeFilters: [
            IndividualFilterCriteria(type: .returnRate, selectedOption: .atLeast8OutOf10)
        ],
        onAddFilter: { _ in },
        onRemoveFilter: { _ in },
        onShowMoreFilters: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
