import SwiftUI

// MARK: - Survey Components
/// Reusable components for satisfaction surveys

// MARK: - Feedback Toggle

struct FeedbackToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(isOn ? color : AppTheme.fontColor.opacity(0.4))
                .frame(width: 24)

            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
                .labelsHidden()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(isOn ? color.opacity(0.1) : AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(1...maxRating, id: \.self) { star in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        rating = star
                    }
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                        .foregroundColor(star <= rating ? starColor(for: rating) : AppTheme.fontColor.opacity(0.3))
                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                }
            }
        }
    }

    private func starColor(for rating: Int) -> Color {
        switch rating {
        case 1: return AppTheme.accentRed
        case 2: return AppTheme.accentOrange
        case 3: return Color.yellow
        case 4: return AppTheme.accentLightBlue
        case 5: return AppTheme.accentGreen
        default: return AppTheme.fontColor.opacity(0.3)
        }
    }
}

// MARK: - Survey Rating Helpers

struct SurveyRatingHelper {
    static func starColor(for rating: Int) -> Color {
        switch rating {
        case 1: return AppTheme.accentRed
        case 2: return AppTheme.accentOrange
        case 3: return Color.yellow
        case 4: return AppTheme.accentLightBlue
        case 5: return AppTheme.accentGreen
        default: return AppTheme.fontColor.opacity(0.3)
        }
    }

    static func ratingText(for rating: Int) -> String {
        switch rating {
        case 1: return "Sehr unzufrieden"
        case 2: return "Unzufrieden"
        case 3: return "Neutral"
        case 4: return "Zufrieden"
        case 5: return "Sehr zufrieden"
        default: return ""
        }
    }
}

// MARK: - Survey Thank You View

struct SurveyThankYouView: View {
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 4))
                .foregroundColor(AppTheme.accentGreen)

            Text("Vielen Dank!")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Ihr Feedback hilft uns, unseren Service kontinuierlich zu verbessern.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                onDismiss()
                dismiss()
            } label: {
                Text("Fertig")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentLightBlue)
                    .foregroundColor(.white)
                    .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Survey Header

struct SurveyHeader: View {
    let ticketNumber: String
    let agentName: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "star.bubble.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.5))
                .foregroundColor(AppTheme.accentOrange)

            Text("Wie war Ihr Support-Erlebnis?")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            VStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Ticket: \(ticketNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text("Bearbeitet von: \(agentName)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }
}

