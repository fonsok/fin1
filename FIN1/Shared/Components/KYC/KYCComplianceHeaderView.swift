import SwiftUI

// MARK: - KYC Compliance Header View

/// Reusable header component for KYC-compliant change request views
struct KYCComplianceHeaderView: View {
    let title: String
    let description: String
    let icon: String

    init(
        title: String = "KYC Verification Required",
        description: String,
        icon: String = "shield.checkered"
    ) {
        self.title = title
        self.description = description
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(self.title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text(self.description)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - KYC Request Status Badge

/// Reusable status badge for KYC change requests
struct KYCRequestStatusBadge: View {
    let status: String
    let color: Color

    var body: some View {
        Text(self.status)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .foregroundColor(self.color)
            .padding(.horizontal, ResponsiveDesign.spacing(10))
            .padding(.vertical, ResponsiveDesign.spacing(4))
            .background(self.color.opacity(0.15))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - KYC Declaration Checkbox

/// Reusable declaration checkbox for KYC forms
struct KYCDeclarationCheckbox: View {
    @Binding var isChecked: Bool
    let text: String

    var body: some View {
        Button(action: { self.isChecked.toggle() }) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.isChecked ? "checkmark.square.fill" : "square")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.isChecked ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.5))

                Text(self.text)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(ResponsiveDesign.spacing(16))
        .background(self.isChecked ? AppTheme.accentGreen.opacity(0.1) : AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - KYC Error Message View

/// Reusable error message view for KYC forms
struct KYCErrorMessageView: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.accentRed)
            Text(self.message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentRed)
            Spacer()
        }
        .padding()
        .background(AppTheme.accentRed.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - KYC Section Header

/// Reusable section header for KYC forms
struct KYCSectionHeader: View {
    let title: String
    let badge: String?
    let badgeColor: Color

    init(title: String, badge: String? = nil, badgeColor: Color = AppTheme.accentGreen) {
        self.title = title
        self.badge = badge
        self.badgeColor = badgeColor
    }

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            if let badge = badge {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(self.badgeColor)
                    Text(badge)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(self.badgeColor)
                }
            }
        }
    }
}

// MARK: - KYC Submit Button

/// Reusable submit button for KYC forms
struct KYCSubmitButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                if self.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.screenBackground))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text(self.title)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ResponsiveDesign.spacing(50))
            .foregroundColor(self.isEnabled && !self.isLoading ? AppTheme.screenBackground : AppTheme.fontColor.opacity(0.5))
            .background(self.isEnabled && !self.isLoading ? AppTheme.accentLightBlue : AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(!self.isEnabled || self.isLoading)
        .padding(.top, ResponsiveDesign.spacing(8))
    }
}

// MARK: - Previews

#Preview("Header") {
    KYCComplianceHeaderView(
        description: "As a regulated financial service, we require verification."
    )
    .padding()
}

#Preview("Status Badge") {
    KYCRequestStatusBadge(status: "Pending Review", color: .orange)
}

#Preview("Declaration") {
    KYCDeclarationCheckbox(isChecked: .constant(true), text: "I accept the terms")
        .padding()
}





