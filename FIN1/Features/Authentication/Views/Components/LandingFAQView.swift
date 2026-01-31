import SwiftUI

/// FAQ section for the landing page
/// Displays frequently asked questions for interested parties
struct LandingFAQView: View {
    @Environment(\.appServices) private var appServices
    @State private var expandedFAQ: String?
    @State private var expandedCategories: Set<String> = [] // categoryId
    @State private var serverFAQs: [FAQContentItem] = []
    @State private var serverCategories: [FAQCategoryContent] = []
    @State private var isLoading: Bool = false
    @State private var loadFailed: Bool = false
    let style: LandingViewModel.DesignStyle

    // MARK: - Constants

    private var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    init(style: LandingViewModel.DesignStyle = .original) {
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(24)) {
            // Separator Line
            Rectangle()
                .fill(style == .typewriter ? Color("InputText") : AppTheme.fontColor.opacity(0.5))
                .frame(height: 1)

            // FAQ Title
            Text(isGerman ? "Häufige Fragen" : "Frequently Asked Questions")
                .font(style == .typewriter
                      ? .system(size: 18, weight: .bold, design: .monospaced)
                      : ResponsiveDesign.headlineFont())
                .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.fontColor)

            if isLoading {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    ProgressView()
                    Text(isGerman ? "Lade FAQs…" : "Loading FAQs…")
                        .font(style == .typewriter
                              ? .system(size: 14, weight: .regular, design: .monospaced)
                              : ResponsiveDesign.bodyFont())
                        .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.secondaryText)
                }
            } else if serverCategories.isEmpty || serverFAQs.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text(isGerman
                         ? "Der FAQ‑Bereich ist gerade nicht verfügbar."
                         : "FAQs are currently unavailable.")
                        .font(style == .typewriter
                              ? .system(size: 14, weight: .regular, design: .monospaced)
                              : ResponsiveDesign.bodyFont())
                        .foregroundColor(style == .typewriter ? Color("InputText") : AppTheme.secondaryText)

                    Button(isGerman ? "Erneut versuchen" : "Retry") {
                        Task { await loadServerFAQsIfAvailable() }
                    }
                    .buttonStyle(.bordered)
                    .tint(style == .typewriter ? Color("InputText") : AppTheme.accentLightBlue)
                    .disabled(isLoading)

                    if loadFailed {
                        Text(isGerman
                             ? "Hinweis: Für die Landing‑FAQs müssen FAQCategory.showOnLanding=true und FAQs veröffentlicht sein."
                             : "Note: Landing FAQs require FAQCategory.showOnLanding=true and published FAQs.")
                            .font(style == .typewriter
                                  ? .system(size: 12, weight: .regular, design: .monospaced)
                                  : ResponsiveDesign.captionFont())
                            .foregroundColor(style == .typewriter ? Color("InputText").opacity(0.7) : AppTheme.fontColor.opacity(0.7))

                        if let hint = connectivityHintText {
                            Text(hint)
                                .font(style == .typewriter
                                      ? .system(size: 12, weight: .regular, design: .monospaced)
                                      : ResponsiveDesign.captionFont())
                                .foregroundColor(style == .typewriter ? Color("InputText").opacity(0.7) : AppTheme.fontColor.opacity(0.7))
                        }
                    }
                }
            } else {
                // Group FAQs by category
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(24)) {
                    ForEach(displayedCategories) { category in
                        let faqs = displayedFAQs(for: category)
                        if !faqs.isEmpty {
                            categorySection(category: category, faqs: faqs)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .task { await loadServerFAQsIfAvailable() }
    }

    private var displayedCategories: [FAQCategoryContent] {
        serverCategories
    }

    private func displayedFAQs(for category: FAQCategoryContent) -> [FAQContentItem] {
        serverFAQs.filter { $0.categoryId == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var connectivityHintText: String? {
        if appServices.parseAPIClient == nil {
            return isGerman
                ? "Debug: Parse ist in der App gerade nicht konfiguriert."
                : "Debug: Parse is not configured in the app."
        }

        let url = (appServices.configurationService.parseServerURL ?? "").lowercased()
        if url.contains("localhost:1338") || url.contains("127.0.0.1:1338") {
            return isGerman
                ? "Debug: Simulator nutzt localhost:1338 → bitte SSH‑Tunnel starten (ssh -L 1338:127.0.0.1:1338 io@192.168.178.24)."
                : "Debug: Simulator uses localhost:1338 → start the SSH tunnel (ssh -L 1338:127.0.0.1:1338 io@192.168.178.24)."
        }

        return nil
    }

    @MainActor
    private func loadServerFAQsIfAvailable() async {
        isLoading = true
        loadFailed = false
        let service = appServices.faqContentService
        do {
            let categories = try await service.fetchFAQCategories(location: "landing")
            let faqs = try await service.fetchFAQsForLanding()
            serverCategories = categories
            serverFAQs = faqs
        } catch {
            loadFailed = true
        }
        isLoading = false
    }


    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(category: FAQCategoryContent, faqs: [FAQContentItem]) -> some View {
        ExpandableSectionRow(
            title: category.title,
            icon: category.icon,
            iconColor: AppTheme.accentLightBlue,
            isExpanded: expandedCategories.contains(category.id),
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedCategories.contains(category.id) {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                }
            },
            style: style
        ) {
            // FAQ Items in this category
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(faqs) { faq in
                    faqRow(faq: faq)
                }
            }
        }
    }

    // MARK: - FAQ Row

    @ViewBuilder
    private func faqRow(faq: FAQContentItem) -> some View {
        ExpandableSectionRow(
            title: faq.question,
            icon: nil,
            iconColor: AppTheme.accentLightBlue,
            isExpanded: expandedFAQ == faq.id,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedFAQ == faq.id {
                        expandedFAQ = nil
                    } else {
                        expandedFAQ = faq.id
                    }
                }
            },
            titleFontWeight: ResponsiveDesign.faqQuestionFontWeight,
            style: style
        ) {
            FAQAnswerFormatter(answer: faq.answer, style: style)
        }
    }
}

#Preview {
    VStack {
        LandingFAQView(style: .original)
        LandingFAQView(style: .typewriter)
    }
    .padding()
}

