//
//  AdminAppSettingsView.swift
//  FIN1
//
//  Admin interface for theme and app configuration
//

import SwiftUI

struct AdminAppSettingsView: View {
    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    // Use AppTheme for reactive theme updates
    private var currentColors: ThemeManager.ThemeColors {
        self.themeManager.colors
    }
    @State private var selectedTargetGroup: ThemeManager.TargetGroup

    init() {
        // Initialize with a default value, will be updated in onAppear
        _selectedTargetGroup = State(initialValue: .standard)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    // Target Group Selection
                    self.targetGroupSection

                    // Theme Preview
                    self.themePreviewSection

                    // Current Configuration Summary
                    self.configurationSummarySection

                    // Apply Changes Button
                    self.applyChangesSection

                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
                .onAppear {
                    self.selectedTargetGroup = self.themeManager.currentTargetGroup
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Target Group Section
    private var targetGroupSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Target Group")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)

            Text("Select the target group to customize the app's appearance and behavior for different user segments.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)

            // Target Group Picker
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(ThemeManager.TargetGroup.allCases, id: \.self) { group in
                    TargetGroupRow(
                        group: group,
                        isSelected: self.selectedTargetGroup == group,
                        isCurrent: self.themeManager.currentTargetGroup == group,
                        onSelect: { self.selectedTargetGroup = group }
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Theme Preview Section
    private var themePreviewSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Theme Preview")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)

            Text(self.selectedTargetGroup.description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)

            // Color Palette Preview
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ResponsiveDesign.spacing(12)) {
                let previewTheme = self.themeManager.getThemeForGroup(self.selectedTargetGroup)
                ColorPreviewCard(title: "Primary", color: previewTheme.primaryBackground)
                ColorPreviewCard(title: "Card", color: previewTheme.cardBackground)
                ColorPreviewCard(title: "Accent", color: previewTheme.accentColor)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Configuration Summary Section
    private var configurationSummarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Current Configuration")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)

            VStack(spacing: ResponsiveDesign.spacing(6)) {
                AdminInfoRow(title: "Active Theme", value: self.themeManager.currentTargetGroup.displayName)
                AdminInfoRow(
                    title: "Commission Rate",
                    value: "\((self.services.configurationService.traderCommissionRate * 100).formatted(.number.precision(.fractionLength(0...2))))%"
                )
                AdminInfoRow(
                    title: "Min Cash Reserve",
                    value: self.services.configurationService.minimumCashReserve.formattedAsLocalizedCurrency()
                )
                AdminInfoRow(
                    title: "Initial Balance",
                    value: self.services.configurationService.initialAccountBalance.formattedAsLocalizedCurrency()
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Apply Changes Section
    private var applyChangesSection: some View {
        Button(action: {
            self.themeManager.switchTargetGroup(self.selectedTargetGroup)
        }) {
            Text("Apply Theme Changes")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    self.selectedTargetGroup == self.themeManager.currentTargetGroup
                        ? AppTheme.primaryText.opacity(0.3)
                        : AppTheme.accentLightBlue
                )
                .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .disabled(self.selectedTargetGroup == self.themeManager.currentTargetGroup)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Target Group Row
struct TargetGroupRow: View {
    let group: ThemeManager.TargetGroup
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: self.onSelect, label: {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(self.group.displayName)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.primaryText)

                        if self.isCurrent {
                            Text("(Active)")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.successGreen)
                        }
                    }

                    Text(self.group.description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentLightBlue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(AppTheme.primaryText.opacity(0.3))
                }
            }
            .padding()
            .background(
                self.isSelected
                    ? AppTheme.accentLightBlue.opacity(0.1)
                    : AppTheme.systemSecondaryBackground
            )
            .cornerRadius(ResponsiveDesign.spacing(8))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .stroke(
                        self.isSelected ? AppTheme.accentLightBlue : AppTheme.primaryText.opacity(0.1),
                        lineWidth: 1
                    )
            )
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Preview Card
struct ColorPreviewCard: View {
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                .fill(self.color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(6))
                        .stroke(AppTheme.primaryText.opacity(0.2), lineWidth: 1)
                )

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
        }
    }
}

#Preview {
    AdminAppSettingsView()
        .environment(\.appServices, .live)
}
