//
//  AdminFinancialSettingsView.swift
//  FIN1
//
//  Admin interface for financial settings (fees, limits, etc.)
//  Wraps and extends ConfigurationManagementView
//

import SwiftUI

struct AdminFinancialSettingsView: View {
    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss

    // State for editing
    @State private var tradingFeePercentage: Double = 0.0025
    @State private var managementFeePercentage: Double = 0.015
    @State private var performanceFeePercentage: Double = 0.20
    @State private var minimumInvestmentAmount: Double = 50.0
    @State private var maximumInvestmentAmount: Double = 1000000.0

    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    // Fee Structure Section
                    feeStructureSection

                    // Investment Limits Section
                    investmentLimitsSection

                    // Tax Settings Section
                    taxSettingsSection

                    // Save Changes Button
                    saveChangesSection

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
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
            .alert("Settings Saved", isPresented: $showSaveSuccess) {
                Button("OK") { dismiss() }
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
                    value: $tradingFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 2,
                    onValueChange: { markAsChanged() }
                )

                FinancialInputRow(
                    title: "Management Fee",
                    value: $managementFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 2,
                    onValueChange: { markAsChanged() }
                )

                FinancialInputRow(
                    title: "Performance Fee",
                    value: $performanceFeePercentage,
                    unit: "%",
                    multiplier: 100,
                    precision: 1,
                    onValueChange: { markAsChanged() }
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
                    value: $minimumInvestmentAmount,
                    unit: "€",
                    multiplier: 1,
                    precision: 0,
                    onValueChange: { markAsChanged() }
                )

                FinancialInputRow(
                    title: "Maximum Investment",
                    value: $maximumInvestmentAmount,
                    unit: "€",
                    multiplier: 1,
                    precision: 0,
                    onValueChange: { markAsChanged() }
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
        Button(action: saveChanges, label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isSaving ? "Saving..." : "Save Changes")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                hasUnsavedChanges
                ? AppTheme.accentLightBlue
                : AppTheme.fontColor.opacity(0.3)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        })
        .disabled(!hasUnsavedChanges || isSaving)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helper Methods

    private func loadCurrentSettings() {
        // Load from UserDefaults or services
        tradingFeePercentage = UserDefaults.standard.object(forKey: "tradingFeePercentage") as? Double ?? 0.0025
        managementFeePercentage = UserDefaults.standard.object(forKey: "managementFeePercentage") as? Double ?? 0.015
        performanceFeePercentage = UserDefaults.standard.object(forKey: "performanceFeePercentage") as? Double ?? 0.20
        minimumInvestmentAmount = UserDefaults.standard.object(forKey: "minimumInvestmentAmount") as? Double ?? 50.0
        maximumInvestmentAmount = UserDefaults.standard.object(forKey: "maximumInvestmentAmount") as? Double ?? 1000000.0
    }

    private func markAsChanged() {
        hasUnsavedChanges = true
    }

    private func saveChanges() {
        isSaving = true

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Save to UserDefaults
            UserDefaults.standard.set(tradingFeePercentage, forKey: "tradingFeePercentage")
            UserDefaults.standard.set(managementFeePercentage, forKey: "managementFeePercentage")
            UserDefaults.standard.set(performanceFeePercentage, forKey: "performanceFeePercentage")
            UserDefaults.standard.set(minimumInvestmentAmount, forKey: "minimumInvestmentAmount")
            UserDefaults.standard.set(maximumInvestmentAmount, forKey: "maximumInvestmentAmount")

            self.isSaving = false
            self.hasUnsavedChanges = false
            self.showSaveSuccess = true
        }
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
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                TextField("0", text: $textValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(6))
                    .foregroundColor(AppTheme.inputFieldText)
                    .onAppear {
                        textValue = formatValue(value * multiplier)
                    }
                    .onChange(of: textValue) { _, newValue in
                        // Filter non-numeric characters
                        let filtered = newValue.filter { "0123456789,.".contains($0) }
                        if filtered != newValue {
                            textValue = filtered
                        }
                    }
                    .onSubmit {
                        if let parsed = parseValue(textValue) {
                            value = parsed / multiplier
                            textValue = formatValue(parsed)
                            onValueChange()
                        }
                    }

                Text(unit)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
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











