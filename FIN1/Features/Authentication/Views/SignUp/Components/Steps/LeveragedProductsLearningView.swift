import SwiftUI

struct LeveragedProductsLearningView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var expandedExampleIDs: Set<String> = []
    @State var highlightedAnchor: LearningAnchor?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(0)) {
                        self.heroHeader
                            .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                            .padding(.top, ResponsiveDesign.spacing(20))
                            .padding(.bottom, ResponsiveDesign.spacing(16))

                        self.topicStrip(proxy: proxy)
                            .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                            .padding(.bottom, ResponsiveDesign.spacing(20))

                        self.stripedBand(index: 0, anchor: .basics) {
                            self.flowSection(
                                icon: "book.closed.fill",
                                title: "Grundlagen",
                                accent: AppTheme.accentLightBlue,
                                body: """
                                Optionsscheine sind börsengehandelte Hebelprodukte auf einen Basiswert (z. B. eine Aktie oder einen Index wie den Dow Jones). \
                                Sie vervielfachen die Kursbewegung des Basiswerts und können innerhalb kurzer Zeit stark steigen oder fallen.
                                """
                            )
                        }

                        self.stripedBand(index: 1, anchor: .call) {
                            self.flowSection(
                                icon: "arrow.up.right.circle.fill",
                                title: "Call-Optionsscheine",
                                accent: AppTheme.accentGreen,
                                body: """
                                Ein Call partizipiert an steigenden Kursen. Fällt der Kurs, verliert ein Call in der Regel an Wert. \
                                Steigt der Kurs, kann der Wert des Calls überproportional zunehmen.
                                """
                            )
                        }

                        self.stripedBand(index: 2, anchor: .put) {
                            self.flowSection(
                                icon: "arrow.down.right.circle.fill",
                                title: "Put-Optionsscheine",
                                accent: AppTheme.accentOrange,
                                body: """
                                Ein Put partizipiert an fallenden Kursen. Fällt z. B. der Dow Jones, kann der Wert eines Put-Optionsscheins steigen. \
                                Steigt der Kurs, verliert ein Put typischerweise an Wert.
                                """
                            )
                        }

                        self.stripedBand(index: 3, anchor: .formulas) {
                            self.formulasSection
                        }

                        self.stripedBand(index: 4, anchor: .examples) {
                            self.workedExamplesSection
                        }

                        self.stripedBand(index: 5, anchor: .metrics) {
                            self.flowSection(
                                icon: "gauge.with.dots.needle.67percent",
                                title: "Funktionsweise & Kennzahlen",
                                accent: AppTheme.accentLightBlue,
                                body: """
                                Wichtige Begriffe: Basiswert, Basispreis (Strike), Laufzeit, Bezugsverhältnis, Hebel und implizite Volatilität. \
                                Der Preis setzt sich aus innerem Wert und Zeitwert zusammen.
                                """
                            )
                        }

                        self.stripedBand(index: 6, anchor: .risks) {
                            self.flowSection(
                                icon: "exclamationmark.triangle.fill",
                                title: "Chancen und Risiken",
                                accent: AppTheme.accentOrange,
                                body: """
                                Hebelprodukte bieten die Chance auf überproportionale Gewinne, bergen aber ein Totalverlustrisiko. \
                                Setzen Sie nur Kapital ein, dessen Verlust Sie verkraften können.
                                """
                            )
                        }

                        self.stripedBand(index: 7, anchor: .note) {
                            self.beforeExpiryCallout
                        }

                        if let externalURL = LeveragedProductsLearningContent.externalURL {
                            self.stripedBand(index: 8, anchor: nil) {
                                self.externalLinkButton(url: externalURL)
                            }
                        }
                    }
                    .padding(.bottom, ResponsiveDesign.spacing(24))
                }
                .background(AppTheme.screenBackground)
            }
            .navigationTitle("Lernseite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}

#Preview {
    LeveragedProductsLearningView()
}
