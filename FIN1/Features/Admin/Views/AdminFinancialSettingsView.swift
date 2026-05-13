//
//  AdminFinancialSettingsView.swift
//  FIN1
//
//  Admin interface for financial settings (fees, limits, etc.)
//  Wraps and extends ConfigurationManagementView
//

import SwiftUI

struct AdminFinancialSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdminFinancialSettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    // Fee Structure Section
                    self.feeStructureSection

                    // Investment Limits Section
                    self.investmentLimitsSection

                    // Tax Settings Section
                    self.taxSettingsSection

                    // Save Changes Button
                    self.saveChangesSection

                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Financial Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .onAppear {
                self.viewModel.loadCurrentSettings()
            }
            .alert("Settings Saved", isPresented: self.$viewModel.showSaveSuccess) {
                Button("OK") { self.dismiss() }
            } message: {
                Text("Your financial settings have been saved successfully.")
            }
        }
    }

    // MARK: - Fee Structure Section
    private var feeStructureSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Fee Structure")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Configure trading and management fees.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                FinancialInputRow(
                    title: "Trading Fee",
                    value: self.$viewModel.tradingFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 2,
                    onValueChange: { self.viewModel.markAsChanged() }
                )

                FinancialInputRow(
                    title: "Management Fee",
                    value: self.$viewModel.managementFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 2,
                    onValueChange: { self.viewModel.markAsChanged() }
                )

                FinancialInputRow(
                    title: "Performance Fee",
                    value: self.$viewModel.performanceFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 1,
                    onValueChange: { self.viewModel.markAsChanged() }
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Investment Limits Section
    private var investmentLimitsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Investment Limits")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Set minimum and maximum investment amounts.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                FinancialInputRow(
                    title: "Minimum Investment",
                    value: self.$viewModel.minimumInvestmentAmount,
                    unit: "€",
                    multiplier: 1,
                    precision: 0,
                    onValueChange: { self.viewModel.markAsChanged() }
                )

                FinancialInputRow(
                    title: "Maximum Investment",
                    value: self.$viewModel.maximumInvestmentAmount,
                    unit: "€",
                    multiplier: 1,
                    precision: 0,
                    onValueChange: { self.viewModel.markAsChanged() }
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Tax Settings Section
    private var taxSettingsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Tax Settings")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("German tax rates (Kapitalertragssteuer).")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                AdminInfoRow(title: "Capital Gains Tax", value: "25%")
                AdminInfoRow(title: "Solidarity Surcharge", value: "5.5%")
                AdminInfoRow(title: "Church Tax (optional)", value: "8-9%")
                AdminInfoRow(title: "Effective Rate", value: "~26.375%")
            }

            Text("Tax rates are set by law and cannot be changed here.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentOrange)
                .padding(.top, ResponsiveDesign.spacing(4))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Save Changes Section
    private var saveChangesSection: some View {
        Button {
            Task {
                await self.viewModel.saveChanges()
            }
        } label: {
            HStack {
                if self.viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(self.viewModel.isSaving ? "Saving..." : "Save Changes")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                self.viewModel.hasUnsavedChanges
                    ? AppTheme.accentLightBlue
                    : AppTheme.fontColor.opacity(0.3)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .disabled(!self.viewModel.hasUnsavedChanges || self.viewModel.isSaving)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Financial Input Row
struct FinancialInputRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let multiplier: Double
    let precision: Int
    let onValueChange: () -> Void

    @State private var textValue: String = ""

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                TextField("0", text: self.$textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(6))
                    .foregroundColor(AppTheme.inputFieldText)
                    .onAppear {
                        self.textValue = self.formatValue(self.value * self.multiplier)
                    }
                    .onChange(of: self.textValue) { _, newValue in
                        // Filter non-numeric characters
                        let filtered = newValue.filter { "0123456789,.".contains($0) }
                        if filtered != newValue {
                            self.textValue = filtered
                        }
                    }
                    .onSubmit {
                        if let parsed = parseValue(textValue) {
                            self.value = parsed / self.multiplier
                            self.textValue = self.formatValue(parsed)
                            self.onValueChange()
                        }
                    }

                Text(self.unit)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = self.precision
        formatter.maximumFractionDigits = self.precision
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(self.precision)f", value)
    }

    private func parseValue(_ text: String) -> Double? {
        let cleanText = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."

        return formatter.number(from: cleanText)?.doubleValue
    }
}

#Preview {
    AdminFinancialSettingsView()
        .environment(\.appServices, .live)
}











