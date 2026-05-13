import SwiftUI

struct InfoBullet: View {
    let text: String
    let color: Color
    
    init(text: String, color: Color = AppTheme.accentLightBlue) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.color)
                .fontWeight(.bold)
            
            Text(self.text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        InfoBullet(text: "This is a sample bullet point")
        InfoBullet(text: "Another bullet point with different text", color: AppTheme.accentGreen)
        InfoBullet(text: "A third bullet point for demonstration purposes")
    }
    .padding()
    .background(AppTheme.sectionBackground)
}
