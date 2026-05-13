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
                selected: self.$selectedTimeRange,
                options: FilterSuccessRateOption.allCases.filter { $0.timePeriod != nil || $0 == .none },
                optionTitle: { $0.displayName }
            )
            .padding(.leading, ResponsiveDesign.horizontalPadding())
            .onChange(of: self.selectedTimeRange) { _, newValue in
                if newValue == .none {
                    self.onRemoveFilter(.timeRange)
                } else {
                    self.onAddFilter(IndividualFilterCriteria(type: .timeRange, successRateOption: newValue))
                }
            }

            // Individual filters (two rows each, leading)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Ø-Return per Trade
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.returnRate.displayName,
                    alignment: .leading,
                    selected: self.$selectedReturnOption,
                    options: ReturnPercentageOption.allCases,
                    optionTitle: { $0.displayName }
                )
                .onChange(of: self.selectedReturnOption) { _, newValue in
                    if newValue == .none {
                        self.onRemoveFilter(.returnRate)
                    } else {
                        self.onAddFilter(IndividualFilterCriteria(type: .returnRate, returnPercentageOption: newValue))
                    }
                }

                // Number of trades
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.numberOfTrades.displayName,
                    alignment: .leading,
                    selected: self.$selectedNumberOfTradesOption,
                    options: NumberOfTradesOption.allCases,
                    optionTitle: { $0.displayName }
                )
                .onChange(of: self.selectedNumberOfTradesOption) { _, newValue in
                    if newValue == .none {
                        self.onRemoveFilter(.numberOfTrades)
                    } else {
                        self.onAddFilter(IndividualFilterCriteria(type: .numberOfTrades, numberOfTradesOption: newValue))
                    }
                }

                // Recent successful trades
                LabeledDropdownRow(
                    label: IndividualFilterCriteria.FilterType.recentSuccessfulTrades.displayName,
                    alignment: .leading,
                    selected: self.$selectedSuccessRateOption,
                    options: FilterSuccessRateOption.allCases.filter { $0.timePeriod == nil },
                    optionTitle: { $0.displayName }
                )
                .onChange(of: self.selectedSuccessRateOption) { _, newValue in
                    if newValue == .none {
                        self.onRemoveFilter(.recentSuccessfulTrades)
                    } else {
                        self.onAddFilter(IndividualFilterCriteria(type: .recentSuccessfulTrades, successRateOption: newValue))
                    }
                }
            }
            .padding(.leading, ResponsiveDesign.horizontalPadding())

            // Show more filters link (leading)
            HStack {
                Button(action: {
                    self.onShowMoreFilters()
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
        .onChange(of: self.activeFilters) { _, _ in
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
                Text(self.label)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                if self.alignment == .center { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: self.alignment == .center ? .center : .leading)

            HStack {
                Button(action: { self.showDropdown.toggle() }, label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(self.optionTitle(self.selected))
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
                .popover(isPresented: self.$showDropdown) {
                    NavigationStack {
                        List(self.options, id: \.self) { option in
                            Button(action: {
                                self.selected = option
                                self.showDropdown = false
                            }) {
                                HStack {
                                    Text(self.optionTitle(option))
                                        .foregroundColor(AppTheme.fontColor)
                                    Spacer()
                                    if option == self.selected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppTheme.accentLightBlue)
                                    }
                                }
                            }
                        }
                        .navigationTitle(self.label)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { self.showDropdown = false }
                                    .foregroundColor(AppTheme.accentLightBlue)
                            }
                        }
                    }
                }
                if self.alignment == .center { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: self.alignment == .center ? .center : .leading)
        }
    }
}

// MARK: - Active filters sync
private extension IndividualFiltersSection {
    func syncSelectedFromActiveFilters() {
        if let time = activeFilters.first(where: { $0.type == .timeRange })?.successRateOption {
            self.selectedTimeRange = time
        } else {
            self.selectedTimeRange = .none
        }

        if let ret = activeFilters.first(where: { $0.type == .returnRate })?.returnPercentageOption {
            self.selectedReturnOption = ret
        } else {
            self.selectedReturnOption = .none
        }

        if let trades = activeFilters.first(where: { $0.type == .numberOfTrades })?.numberOfTradesOption {
            self.selectedNumberOfTradesOption = trades
        } else {
            self.selectedNumberOfTradesOption = .none
        }

        if let recent = activeFilters.first(where: { $0.type == .recentSuccessfulTrades })?.successRateOption {
            self.selectedSuccessRateOption = recent
        } else {
            self.selectedSuccessRateOption = .none
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
