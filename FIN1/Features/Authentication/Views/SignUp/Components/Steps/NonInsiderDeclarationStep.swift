import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct NonInsiderDeclarationStep: View {
    @Binding var insiderTradingOptions: [String: Bool]
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Insider-Handel vermeiden")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)
            
            Text("Kennzeichnen Sie die korrekten Aussagen.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Text("(Auf die meisten Personen wird keine der folgenden Aussagen zutreffen.)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Ich oder eines meiner unmittelbaren Familienmitglieder sind:")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    // Option 1: Brokerage or Stock Exchange Employee
                    Button(action: {
                        self.insiderTradingOptions["Brokerage or Stock Exchange Employee"]?.toggle()
                        // If this is selected, uncheck "None of the above"
                        if self.insiderTradingOptions["Brokerage or Stock Exchange Employee"] == true {
                            self.insiderTradingOptions["None of the above"] = false
                        }
                    }) {
                        HStack {
                            InteractiveElement(
                                isSelected: self.insiderTradingOptions["Brokerage or Stock Exchange Employee"] == true,
                                type: .checkbox
                            )
                            
                            Text("Angestellt bei einem Brokerunternehmen oder einer Wertpapierbörse.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Option 2: Director or 10% Shareholder
                    Button(action: {
                        self.insiderTradingOptions["Director or 10% Shareholder"]?.toggle()
                        // If this is selected, uncheck "None of the above"
                        if self.insiderTradingOptions["Director or 10% Shareholder"] == true {
                            self.insiderTradingOptions["None of the above"] = false
                        }
                    }) {
                        HStack {
                            InteractiveElement(
                                isSelected: self.insiderTradingOptions["Director or 10% Shareholder"] == true,
                                type: .checkbox
                            )
                            
                            Text("Ein Direktor oder ein zu 10 % Anteilseigner einer börsennotierten Gesellschaft.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Option 3: High-Ranking Official
                    Button(action: {
                        self.insiderTradingOptions["High-Ranking Official"]?.toggle()
                        // If this is selected, uncheck "None of the above"
                        if self.insiderTradingOptions["High-Ranking Official"] == true {
                            self.insiderTradingOptions["None of the above"] = false
                        }
                    }) {
                        HStack {
                            InteractiveElement(
                                isSelected: self.insiderTradingOptions["High-Ranking Official"] == true,
                                type: .checkbox
                            )
                            
                            Text("Ein derzeitiger oder ehemaliger hoher Beamter, der gewählt oder ernannt wurde.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Option 4: None of the above
                    Button(action: {
                        self.insiderTradingOptions["None of the above"]?.toggle()
                        // If "None of the above" is selected, uncheck all others
                        if self.insiderTradingOptions["None of the above"] == true {
                            self.insiderTradingOptions["Brokerage or Stock Exchange Employee"] = false
                            self.insiderTradingOptions["Director or 10% Shareholder"] = false
                            self.insiderTradingOptions["High-Ranking Official"] = false
                        }
                    }) {
                        HStack {
                            InteractiveElement(
                                isSelected: self.insiderTradingOptions["None of the above"] == true,
                                type: .checkbox
                            )
                            
                            Text("Keine dieser Aussagen treffen auf mich zu.")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

#Preview {
    NonInsiderDeclarationStep(insiderTradingOptions: .constant([
        "Brokerage or Stock Exchange Employee": false,
        "Director or 10% Shareholder": false,
        "High-Ranking Official": false,
        "None of the above": true
    ]))
    .background(AppTheme.screenBackground)
}
