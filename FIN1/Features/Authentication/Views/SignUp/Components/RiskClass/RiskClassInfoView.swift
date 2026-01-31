import SwiftUI

struct RiskClassInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        // Header
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            Text("Risikoklassen")
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)

                            Text("Synthetic Risk and Reward Indicator (SRI) nach EU-Standard")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Risk Classes
                        VStack(spacing: ResponsiveDesign.spacing(16)) {
                            ForEach(RiskClass.allCases, id: \.rawValue) { riskClass in
                                RiskClassCard(riskClass: riskClass)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                    }
                }
            }
            .navigationTitle("Risikoklassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

struct RiskClassCard: View {
    let riskClass: RiskClass

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header
            HStack {
                Text(riskClass.displayName)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                // Risk indicator
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    ForEach(1...7, id: \.self) { index in
                        Circle()
                            .fill(index <= riskClass.rawValue ? riskClass.color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Description
            Text(riskClass.description)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)

            // Examples
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Examples:")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(riskClass.examples)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(riskClass.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    RiskClassInfoView()
}
