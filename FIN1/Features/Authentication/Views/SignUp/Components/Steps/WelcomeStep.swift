import SwiftUI

// Import UI components
// Note: These components are now in the UI subfolder

struct WelcomeStep: View {
    @Binding var accountType: AccountType
    @Binding var userRole: UserRole

    var body: some View {
        SignUpStepList {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Herzlich willkommen")
                    .font(ResponsiveDesign.isCompactDevice() ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Konto eröffnen – einfach und kostenlos.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .signUpListSection(stripeIndex: 0)

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Ich eröffne das Konto als")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    Button(action: { self.accountType = .individual }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.accountType == .individual,
                                type: .radioButton,
                                color: AppTheme.accentLightBlue
                            )

                            Text("Einzelperson")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { self.accountType = .company }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.accountType == .company,
                                type: .radioButton,
                                color: AppTheme.accentLightBlue
                            )

                            Text("Firma")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .signUpListSection(stripeIndex: 1)

            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Text("Ich bin")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    Button(action: { self.userRole = .investor }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.userRole == .investor,
                                type: .radioButton,
                                color: AppTheme.accentLightBlue
                            )

                            Text("Investor")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        guard self.accountType != .company else { return }
                        self.userRole = .trader
                    }, label: {
                        HStack {
                            InteractiveElement(
                                isSelected: self.userRole == .trader,
                                type: .radioButton,
                                color: self.accountType == .company
                                    ? AppTheme.fontColor.opacity(0.3)
                                    : AppTheme.accentLightBlue
                            )

                            Text("Trader")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(
                                    self.accountType == .company
                                        ? AppTheme.fontColor.opacity(0.4)
                                        : AppTheme.fontColor
                                )

                            if self.accountType == .company {
                                Text("(nur für Einzelpersonen)")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
                            }

                            Spacer()
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                    .disabled(self.accountType == .company)
                }
            }
            .signUpListSection(stripeIndex: 2)
            .onChange(of: self.accountType) { _, newType in
                if newType == .company && self.userRole == .trader {
                    self.userRole = .investor
                }
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Zur Kontoführung benötigen wir folgende Informationen:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    if self.accountType == .company {
                        InfoBullet(text: "Angaben zum Unternehmen (Firma, Rechtsform, Registerdaten).")
                        InfoBullet(text: "Eingetragener Sitz und ggf. Geschäftsanschrift.")
                        InfoBullet(text: "Steuerliche Identifikatoren (USt-IdNr. oder Steuernummer).")
                        InfoBullet(text: "Wirtschaftlich Berechtigte (UBOs) mit Name, Geburtsdatum, Staatsangehörigkeit.")
                        InfoBullet(text: "Vertretungsberechtigte Personen und deren Funktion.")
                        InfoBullet(text: "Erklärungen zu PEP-Status, Sanktionen und Richtigkeit der Angaben.")
                        InfoBullet(text: "Angaben zur vertretungsberechtigten Person (persönliche KYC-Daten).")
                    } else {
                        InfoBullet(text: "Angaben zur Person und Adressdaten (laut Ausweisdokumenten).")
                        InfoBullet(text: "Informationen zum Einkommen und steuerlichen Wohnsitz.")
                        InfoBullet(text: "Informationen zur Handelserfahrung und Anlagezielen.")
                        InfoBullet(text: "Daten zum Bankkonto")
                    }
                }
            }
            .signUpListSection(stripeIndex: 3)

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Bitte halten Sie bereit:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    if self.accountType == .company {
                        InfoBullet(text: "Aktueller Handelsregisterauszug (nicht älter als 6 Monate)")
                        InfoBullet(text: "USt-IdNr. oder nationale Steuernummer des Unternehmens")
                        InfoBullet(text: "Gesellschaftsvertrag / Satzung (falls abweichend vom Register)")
                        InfoBullet(text: "Transparenzregisterauszug (falls zutreffend)")
                        InfoBullet(text: "Personalausweis oder Reisepass der vertretungsberechtigten Person")
                    } else {
                        InfoBullet(text: "Ihre Steuernummer")
                        InfoBullet(text: "Kopie (.png-Datei) Ihres Personalausweis (Vorder- und Rückseite) oder Ihres Reisepasses")
                        InfoBullet(
                            text: "Kopie (.png-Datei) eines plausiblen Adressnachweises (z.B. Kontoauszug, Rechnung Energieversorger, Kreditkartenabrechnung)"
                        )
                    }
                }
            }
            .signUpListSection(stripeIndex: 4)

            Button(action: {
                // Handle continue application action
            }) {
                HStack {
                    Text("Sie möchten mit einem bereits angelegten Antrag fortfahren?")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))

                    Text("Klicken Sie hier")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.accentLightBlue)

                    Image(systemName: "arrow.up.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .signUpListSection(stripeIndex: 5)
        }
    }
}

#Preview {
    WelcomeStep(
        accountType: .constant(.individual),
        userRole: .constant(.investor)
    )
    .background(AppTheme.screenBackground)
}
