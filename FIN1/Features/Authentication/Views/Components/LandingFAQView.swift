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
                .fill(self.style == .typewriter ? Color("InputText") : AppTheme.fontColor.opacity(0.5))
                .frame(height: 1)

            // FAQ Title
            Text(self.isGerman ? "Häufige Fragen" : "Frequently Asked Questions")
                .font(self.style == .typewriter
                    ? .system(size: 18, weight: .bold, design: .monospaced)
                    : ResponsiveDesign.headlineFont())
                .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.fontColor)

            if self.isLoading {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    ProgressView()
                    Text(self.isGerman ? "Lade FAQs…" : "Loading FAQs…")
                        .font(self.style == .typewriter
                            ? .system(size: 14, weight: .regular, design: .monospaced)
                            : ResponsiveDesign.bodyFont())
                        .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.secondaryText)
                }
            } else if self.serverCategories.isEmpty || self.serverFAQs.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text(self.isGerman
                        ? "Der FAQ‑Bereich ist gerade nicht verfügbar.\n(Evtl. Einstellungen⇒Apps⇒...Lokales Netzwerk Zugriff erlauben.)"
                        : "FAQs are currently unavailable.")
                        .font(self.style == .typewriter
                            ? .system(size: 14, weight: .regular, design: .monospaced)
                            : ResponsiveDesign.bodyFont())
                        .foregroundColor(self.style == .typewriter ? Color("InputText") : AppTheme.secondaryText)

                    Button(self.isGerman ? "Erneut versuchen" : "Retry") {
                        Task { await self.loadServerFAQsIfAvailable(forceRefresh: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentLightBlue)
                    .foregroundStyle(Color.white)
                    .disabled(self.isLoading)

                    if self.loadFailed {
                        Text(self.isGerman
                            ? "Hinweis: Für die Landing‑FAQs müssen FAQCategory.showOnLanding=true und FAQs veröffentlicht sein."
                            : "Note: Landing FAQs require FAQCategory.showOnLanding=true and published FAQs.")
                            .font(self.style == .typewriter
                                ? .system(size: 12, weight: .regular, design: .monospaced)
                                : ResponsiveDesign.captionFont())
                            .foregroundColor(self.style == .typewriter ? Color("InputText").opacity(0.7) : AppTheme.fontColor.opacity(0.7))

                        if let hint = connectivityHintText {
                            Text(hint)
                                .font(self.style == .typewriter
                                    ? .system(size: 12, weight: .regular, design: .monospaced)
                                    : ResponsiveDesign.captionFont())
                                .foregroundColor(
                                    self.style == .typewriter ? Color("InputText").opacity(0.7) : AppTheme.fontColor.opacity(0.7)
                                )
                        }
                    }
                }
            } else {
                // Group FAQs by category
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(24)) {
                    ForEach(self.displayedCategories) { category in
                        let faqs = self.displayedFAQs(for: category)
                        if !faqs.isEmpty {
                            self.categorySection(category: category, faqs: faqs)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .task { await self.loadServerFAQsIfAvailable(forceRefresh: false) }
    }

    private var displayedCategories: [FAQCategoryContent] {
        self.serverCategories
    }

    private func displayedFAQs(for category: FAQCategoryContent) -> [FAQContentItem] {
        self.serverFAQs.filter { $0.categoryId == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var connectivityHintText: String? {
        if self.appServices.parseAPIClient == nil {
            return self.isGerman
                ? "Debug: Parse ist in der App gerade nicht konfiguriert."
                : "Debug: Parse is not configured in the app."
        }

        let url = (appServices.configurationService.parseServerURL ?? "").lowercased()
        if url.contains("localhost:8443") || url.contains("127.0.0.1:8443") {
            return self.isGerman
                ? "Debug: Simulator nutzt https://localhost:8443 → SSH‑Tunnel: ssh -L 8443:127.0.0.1:443 io@192.168.178.24"
                : "Debug: Simulator uses https://localhost:8443 → SSH tunnel: ssh -L 8443:127.0.0.1:443 io@192.168.178.24"
        }
        if url.contains("localhost:1338") || url.contains("127.0.0.1:1338") {
            return self.isGerman
                ? "Debug: Simulator nutzt localhost:1338 → SSH‑Tunnel zum Parse-Host: ssh -L 1338:127.0.0.1:1338 user@<server-ip>"
                : "Debug: Simulator uses localhost:1338 → SSH tunnel to Parse host: ssh -L 1338:127.0.0.1:1338 user@<server-ip>"
        }

        return nil
    }

    private func loadServerFAQsIfAvailable(forceRefresh: Bool = false) async {
        await MainActor.run {
            self.isLoading = true
            self.loadFailed = false
        }

        let service = self.appServices.faqContentService
        do {
            if forceRefresh {
                await service.clearCache(location: "landing", userRole: nil)
            }
            // Fetch off the main actor to avoid blocking UI interactions if the underlying
            // implementation performs any synchronous work.
            let categories = try await service.fetchFAQCategories(location: "landing")
            let faqs = try await service.fetchFAQsForLanding()
            await MainActor.run {
                self.serverCategories = categories
                self.serverFAQs = faqs
            }
        } catch {
            await MainActor.run {
                self.loadFailed = true
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }


    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(category: FAQCategoryContent, faqs: [FAQContentItem]) -> some View {
        ExpandableSectionRow(
            title: category.title,
            icon: category.icon,
            iconColor: AppTheme.accentLightBlue,
            isExpanded: self.expandedCategories.contains(category.id),
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if self.expandedCategories.contains(category.id) {
                        self.expandedCategories.remove(category.id)
                    } else {
                        self.expandedCategories.insert(category.id)
                    }
                }
            },
            // Do not indent nested FAQ "cards" based on the category icon.
            // The icon alignment indent is useful for text content, but here it creates excessive left whitespace.
            contentLeadingPaddingOverride: 0,
            style: self.style
        ) {
            // FAQ Items in this category
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(faqs) { faq in
                    self.faqRow(faq: faq)
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
            isExpanded: self.expandedFAQ == faq.id,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if self.expandedFAQ == faq.id {
                        self.expandedFAQ = nil
                    } else {
                        self.expandedFAQ = faq.id
                    }
                }
            },
            titleFontWeight: ResponsiveDesign.faqQuestionFontWeight,
            style: self.style
        ) {
            FAQAnswerFormatter(answer: faq.answer, style: self.style)
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

