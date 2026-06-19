import SwiftUI

// MARK: - Summary Components
struct SummarySection<Content: View>: View {
    let title: String
    let stripeIndex: Int
    let content: Content

    init(title: String, stripeIndex: Int, @ViewBuilder content: () -> Content) {
        self.title = title
        self.stripeIndex = stripeIndex
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                self.content
            }
        }
        .signUpListSection(stripeIndex: self.stripeIndex)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: self.icon)
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(20))

            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }
}

#Preview {
    SignUpStepList {
        SummarySection(title: "Account Information", stripeIndex: 0) {
            SummaryRow(label: "Account Type", value: "Individual", icon: "person.2.fill")
            SummaryRow(label: "User Role", value: "Investor", icon: "person.crop.circle.fill")
        }

        SummarySection(title: "Contact Information", stripeIndex: 1) {
            SummaryRow(label: "Email", value: "test@example.com", icon: "envelope.fill")
            SummaryRow(label: "Phone", value: "+49123456789", icon: "phone.fill")
        }
    }
    .background(AppTheme.screenBackground)
}
