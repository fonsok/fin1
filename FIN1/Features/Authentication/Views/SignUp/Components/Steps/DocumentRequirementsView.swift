import SwiftUI

struct DocumentRequirementsView: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Anforderungen an den Adressnachweis")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Accepted Documents
            RequirementSection(
                title: "Beispiele:",
                items: [
                    "Kontoauszug",
                    "Rechnung (Energie-)Versorger",
                    "Kreditkartenabrechnung",
                    "Rechnung Telefon-/Internetanbieter"
                ]
            )
            
            // Required Information
            RequirementSection(
                title: "Der Adressnachweis muss folgendes beinhalten:",
                items: [
                    "Ihren vollständigen Namen",
                    "Ihre aktuelle Wohnanschrift",
                    "Ausgebendes Unternehmen/Logo",
                    "Ausstellungsdatum (nicht älter als 3 Monate)"
                ]
            )
            
            // Not Valid Documents
            RequirementSection(
                title: "Nicht gültig:",
                items: [
                    "Scheck",
                    "Versicherung",
                    "Quittung u.ä."
                ],
                textColor: AppTheme.accentRed
            )
            
            // File Format Requirements
            RequirementSection(
                title: "Dateiformat:",
                items: [
                    "Bild (GIF, JPG, PNG, TIF und PDF)",
                    "300 dpi minimale Auflösung"
                ]
            )
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

struct RequirementSection: View {
    let title: String
    let items: [String]
    let textColor: Color
    
    init(title: String, items: [String], textColor: Color = AppTheme.fontColor) {
        self.title = title
        self.items = items
        self.textColor = textColor
    }
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(self.items, id: \.self) { item in
                    InfoBullet(text: item, color: self.textColor)
                }
            }
        }
    }
}

#Preview {
    DocumentRequirementsView()
        .background(AppTheme.screenBackground)
}
