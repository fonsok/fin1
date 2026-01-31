import SwiftUI

// MARK: - Summary Components
struct SummarySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
            
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                content
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: 20)
            
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        SummarySection(title: "Account Information") {
            SummaryRow(label: "Account Type", value: "Individual", icon: "person.2.fill")
            SummaryRow(label: "User Role", value: "Investor", icon: "person.crop.circle.fill")
        }
        
        SummarySection(title: "Contact Information") {
            SummaryRow(label: "Email", value: "test@example.com", icon: "envelope.fill")
            SummaryRow(label: "Phone", value: "+49123456789", icon: "phone.fill")
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}
