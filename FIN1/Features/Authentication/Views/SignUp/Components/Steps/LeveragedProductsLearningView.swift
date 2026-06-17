import SwiftUI

struct LeveragedProductsLearningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var expandedExampleIDs: Set<String> = []
    @State private var highlightedAnchor: LearningAnchor?

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

    // MARK: - Header & navigation

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accentLightBlue.opacity(0.38),
                            AppTheme.accentLightBlue.opacity(0.1),
                            AppTheme.sectionBackground.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
                Label("Optionsscheine verstehen", systemImage: "graduationcap.fill")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Call/Put-Optionsscheine einfach erklärt")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Grundlagen, Funktionsweise, Kennzahlen, Praxisbeispiele, Chancen und Risiken")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.78))
            }
            .padding(ResponsiveDesign.spacing(20))
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
    }

    private func topicStrip(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(LearningAnchor.chipAnchors) { anchor in
                    self.topicChip(anchor: anchor, proxy: proxy)
                }
            }
            .padding(.vertical, ResponsiveDesign.spacing(4))
        }
    }

    private func topicChip(anchor: LearningAnchor, proxy: ScrollViewProxy) -> some View {
        let isSelected = self.highlightedAnchor == anchor

        return Button {
            self.highlightedAnchor = anchor
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(anchor.id, anchor: .top)
            }
        } label: {
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: anchor.icon)
                    .font(ResponsiveDesign.captionFont())
                Text(anchor.chipTitle)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
            }
            .foregroundColor(anchor.accentColor)
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(anchor.accentColor.opacity(isSelected ? 0.28 : 0.12))
            .overlay(
                Capsule()
                    .stroke(anchor.accentColor.opacity(isSelected ? 0.65 : 0), lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Striped layout (admin-portal list row striping)

    private func stripedBand<Content: View>(
        index: Int,
        anchor: LearningAnchor?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                self.listRowStripeBackground(index: index)
            }
            .id(anchor?.id)
    }

    /// Subtle zebra striping on the blue page background (admin-portal style, low contrast).
    @ViewBuilder
    private func listRowStripeBackground(index: Int) -> some View {
        ZStack {
            AppTheme.screenBackground
            if index.isMultiple(of: 2) {
                Color.white.opacity(0.035)
            } else {
                Color.black.opacity(0.03)
            }
        }
    }

    // MARK: - Sections

    private func flowSection(icon: String, title: String, accent: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10)))

                Text(title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer(minLength: 0)
            }

            Text(body)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.82))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formulasSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(14)) {
            self.sectionDivider(title: "Formeln zum Laufzeitende", icon: "function")

            Text(LeveragedProductsLearningExamples.formulaIntro)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.82))

            self.formulaCard(
                label: "Call",
                formula: LeveragedProductsLearningExamples.callFormulaAtExpiry,
                accent: AppTheme.accentGreen
            )
            self.formulaCard(
                label: "Put",
                formula: LeveragedProductsLearningExamples.putFormulaAtExpiry,
                accent: AppTheme.accentOrange
            )

            Text(LeveragedProductsLearningExamples.examplesIntro)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }

    private var workedExamplesSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            self.sectionDivider(title: "Rechenbeispiele", icon: "list.number")

            self.workedExampleAccordion(
                id: "call-example",
                title: "Call auf Aktie XYZ",
                subtitle: "Spekulation auf steigende Kurse",
                icon: "arrow.up.right.circle.fill",
                accent: AppTheme.accentGreen,
                setup: LeveragedProductsLearningExamples.callExampleSetup,
                scenarios: [
                    .init(title: "Gewinn — Kurs steigt auf 130 €", tone: .gain, text: LeveragedProductsLearningExamples.callScenarioAGain),
                    .init(title: "Verlust — Kurs unter 100 €", tone: .loss, text: LeveragedProductsLearningExamples.callScenarioBLoss)
                ]
            )

            self.workedExampleAccordion(
                id: "put-example",
                title: "Put auf Aktie XYZ",
                subtitle: "Spekulation auf fallende Kurse",
                icon: "arrow.down.right.circle.fill",
                accent: AppTheme.accentOrange,
                setup: LeveragedProductsLearningExamples.putExampleSetup,
                scenarios: [
                    .init(title: "Gewinn — Kurs fällt auf 40 €", tone: .gain, text: LeveragedProductsLearningExamples.putScenarioAGain),
                    .init(title: "Verlust — Kurs über 50 €", tone: .loss, text: LeveragedProductsLearningExamples.putScenarioBLoss)
                ]
            )

            self.workedExampleAccordion(
                id: "bmw-example",
                title: "Call auf BMW AG",
                subtitle: "Konkretes Aktienbeispiel",
                icon: "car.fill",
                accent: AppTheme.accentLightBlue,
                setup: LeveragedProductsLearningExamples.bmwExampleBody,
                scenarios: []
            )
        }
    }

    private var beforeExpiryCallout: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.top, 2)

            Text(LeveragedProductsLearningExamples.beforeExpiryNote)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.85))
                .multilineTextAlignment(.leading)
        }
        .padding(ResponsiveDesign.spacing(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(AppTheme.accentLightBlue)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
    }

    private func externalLinkButton(url: URL) -> some View {
        Button {
            self.openURL(url)
        } label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "safari")
                    .font(ResponsiveDesign.headlineFont())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weitere Informationen im Internet")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                    Text("Externe Ressource öffnen")
                        .font(ResponsiveDesign.captionFont())
                        .opacity(0.75)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.screenBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Components

    private func sectionDivider(title: String, icon: String) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(10)) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accentLightBlue)
            Text(title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Spacer(minLength: 0)
        }
    }

    private func formulaCard(label: String, formula: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(label.uppercased())
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.bold)
                .foregroundColor(accent)

            Text(formula)
                .font(ResponsiveDesign.monospacedFont(size: 14, weight: .medium))
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.leading)
        }
        .padding(ResponsiveDesign.spacing(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.screenBackground.opacity(0.45))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(accent)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12)))
    }

    private func workedExampleAccordion(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        setup: String,
        scenarios: [LearningScenarioItem]
    ) -> some View {
        let isExpanded = self.expandedExampleIDs.contains(id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isExpanded {
                        self.expandedExampleIDs.remove(id)
                    } else {
                        self.expandedExampleIDs.insert(id)
                    }
                }
            } label: {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(accent)
                        .frame(width: 40, height: 40)
                        .background(accent.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                        Text(subtitle)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.65))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .padding(ResponsiveDesign.spacing(16))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text(setup)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.85))
                        .multilineTextAlignment(.leading)

                    ForEach(scenarios) { scenario in
                        self.scenarioCard(scenario)
                    }
                }
                .padding(.horizontal, ResponsiveDesign.spacing(16))
                .padding(.bottom, ResponsiveDesign.spacing(16))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.screenBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(14)))
    }

    private func scenarioCard(_ scenario: LearningScenarioItem) -> some View {
        let accent = scenario.tone == .gain ? AppTheme.accentGreen : AppTheme.accentOrange
        let icon = scenario.tone == .gain ? "plus.circle.fill" : "minus.circle.fill"

        return HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Label(scenario.title, systemImage: icon)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(accent)

                Text(scenario.text)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sectionBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10)))
    }
}

// MARK: - Scroll anchors

private enum LearningAnchor: String, CaseIterable, Identifiable {
    case basics
    case call
    case put
    case formulas
    case examples
    case metrics
    case risks
    case note

    var id: String { rawValue }

    static var chipAnchors: [LearningAnchor] {
        [.basics, .call, .put, .formulas, .examples, .risks]
    }

    var chipTitle: String {
        switch self {
        case .basics: return "Grundlagen"
        case .call: return "Call"
        case .put: return "Put"
        case .formulas: return "Formeln"
        case .examples: return "Beispiele"
        case .metrics: return "Kennzahlen"
        case .risks: return "Risiken"
        case .note: return "Hinweis"
        }
    }

    var icon: String {
        switch self {
        case .basics: return "book.closed.fill"
        case .call: return "arrow.up.right"
        case .put: return "arrow.down.right"
        case .formulas: return "function"
        case .examples: return "list.number"
        case .metrics: return "gauge.with.dots.needle.67percent"
        case .risks: return "exclamationmark.triangle"
        case .note: return "clock.badge.exclamationmark"
        }
    }

    var accentColor: Color {
        switch self {
        case .basics, .formulas, .metrics, .note: return AppTheme.accentLightBlue
        case .call, .examples: return AppTheme.accentGreen
        case .put, .risks: return AppTheme.accentOrange
        }
    }
}

// MARK: - Scenario model

private struct LearningScenarioItem: Identifiable {
    enum Tone {
        case gain
        case loss
    }

    let id = UUID()
    let title: String
    let tone: Tone
    let text: String
}

#Preview {
    LeveragedProductsLearningView()
}
