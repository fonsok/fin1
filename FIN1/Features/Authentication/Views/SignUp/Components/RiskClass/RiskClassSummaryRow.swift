import SwiftUI

struct RiskClassSummaryRow: View {
    let signUpData: SignUpData
    @State private var showRiskClassInfo = false
    
    var body: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: 20)
            
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Risikoklasse")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                
                // Info button
                Button(action: {
                    showRiskClassInfo = true
                }) {
                    Text("ⓘ")
                        .foregroundColor(AppTheme.accentLightBlue)
                        .font(ResponsiveDesign.captionFont())
                }
            }
            
            Spacer()
            
            Text(": \(signUpData.finalRiskClass.shortName)")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showRiskClassInfo) {
            RiskClassInfoView()
        }
    }
}

#Preview {
    RiskClassSummaryRow(signUpData: SignUpData())
        .padding()
        .background(AppTheme.sectionBackground)
}
