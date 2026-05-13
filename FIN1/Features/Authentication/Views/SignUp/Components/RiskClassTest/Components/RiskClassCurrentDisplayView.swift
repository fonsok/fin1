import SwiftUI

struct RiskClassCurrentDisplayView: View {
    let signUpData: SignUpData
    let calculateCurrentScore: () -> Int
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Current Risk Class")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
            
            Text("\(self.signUpData.finalRiskClass.displayName)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(self.signUpData.finalRiskClass.color)
                .padding()
                .background(self.signUpData.finalRiskClass.color.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            
            Text("Score: \(self.calculateCurrentScore()) points")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

#Preview {
    RiskClassCurrentDisplayView(
        signUpData: SignUpData(),
        calculateCurrentScore: { 15 }
    )
    .padding()
    .background(AppTheme.screenBackground)
}
