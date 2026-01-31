import SwiftUI

struct DesiredReturnStep: View {
    @Binding var desiredReturn: DesiredReturn

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Desired Return")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("What is your desired return on investment?")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)

            // Desired Return Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select your desired return:")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Menu {
                    ForEach(DesiredReturn.allCases, id: \.self) { option in
                        Button(action: { self.desiredReturn = option }, label: {
                            Text(option.displayName)
                                .foregroundColor(AppTheme.inputFieldText)
                        })
                    }
                } label: {
                    HStack {
                        Text(desiredReturn.displayName)
                            .foregroundColor(AppTheme.inputFieldText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(AppTheme.inputFieldText)
                    }
                    .padding()
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }

            // Risk Warning
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                        .font(ResponsiveDesign.headlineFont())

                    Text("Risk Warning")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Spacer()
                }

                Text("Trading leveraged products involves a risk of loss of up to 100% of the capital invested.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(AppTheme.accentOrange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(12))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    DesiredReturnStep(desiredReturn: .constant(.atLeastTenPercent))
        .background(AppTheme.screenBackground)
}
