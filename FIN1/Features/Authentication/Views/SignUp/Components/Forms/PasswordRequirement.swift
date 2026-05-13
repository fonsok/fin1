import SwiftUI

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: self.isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(self.isMet ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
                .font(ResponsiveDesign.captionFont())
            
            Text(self.text)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(self.isMet ? AppTheme.fontColor : AppTheme.fontColor.opacity(0.6))
            
            Spacer()
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        PasswordRequirement(text: "At least 8 characters", isMet: true)
        PasswordRequirement(text: "Contains uppercase letter", isMet: false)
        PasswordRequirement(text: "Contains number", isMet: true)
    }
    .padding()
    .background(AppTheme.sectionBackground)
}
