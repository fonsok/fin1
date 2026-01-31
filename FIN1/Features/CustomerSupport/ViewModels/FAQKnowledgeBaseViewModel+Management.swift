import Foundation

// MARK: - FAQKnowledgeBaseViewModel + Article Management
/// Extension handling article CRUD operations

extension FAQKnowledgeBaseViewModel {

    // MARK: - Article Management

    func startCreateArticle() {
        resetArticleForm()
        showCreateArticleSheet = true
    }

    func startEditArticle(_ article: FAQArticle) {
        editingArticle = article
        newArticleTitle = article.title
        newArticleSummary = article.summary
        newArticleContent = article.content
        newArticleCategory = article.category
        newArticleTags = article.tags
        newArticleKeywords = article.keywords
        showEditArticleSheet = true
    }

    func createArticle(createdBy: String) async {
        guard validateArticleForm() else { return }

        isLoading = true
        defer {
            isLoading = false
            showCreateArticleSheet = false
        }

        do {
            let create = FAQArticleCreate(
                title: newArticleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: newArticleSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                content: newArticleContent.trimmingCharacters(in: .whitespacesAndNewlines),
                category: newArticleCategory,
                tags: newArticleTags,
                keywords: newArticleKeywords,
                sourceTicketIds: [],
                solutionType: nil,
                relatedHelpCenterArticleId: nil
            )

            let article = try await faqService.createArticle(create, createdBy: createdBy)
            showSuccessMessage("Artikel '\(article.title)' erstellt")
            resetArticleForm()
            await load()
        } catch {
            handleError(error)
        }
    }

    func updateArticle(updatedBy: String) async {
        guard let article = editingArticle else { return }
        guard validateArticleForm() else { return }

        isLoading = true
        defer {
            isLoading = false
            showEditArticleSheet = false
        }

        do {
            let update = FAQArticleUpdate(
                title: newArticleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: newArticleSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                content: newArticleContent.trimmingCharacters(in: .whitespacesAndNewlines),
                category: newArticleCategory,
                tags: newArticleTags,
                keywords: newArticleKeywords,
                isPublished: nil
            )

            let updated = try await faqService.updateArticle(
                articleId: article.id,
                update: update,
                updatedBy: updatedBy
            )
            showSuccessMessage("Artikel '\(updated.title)' aktualisiert")
            editingArticle = nil
            resetArticleForm()
            await load()
        } catch {
            handleError(error)
        }
    }

    func publishArticle(_ article: FAQArticle) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await faqService.publishArticle(articleId: article.id)
            showSuccessMessage("Artikel veröffentlicht")
            await load()
        } catch {
            handleError(error)
        }
    }

    func unpublishArticle(_ article: FAQArticle) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await faqService.unpublishArticle(articleId: article.id)
            showSuccessMessage("Artikel als Entwurf gespeichert")
            await load()
        } catch {
            handleError(error)
        }
    }

    func archiveArticle(_ article: FAQArticle) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await faqService.archiveArticle(articleId: article.id)
            showSuccessMessage("Artikel archiviert")
            deselectArticle()
            await load()
        } catch {
            handleError(error)
        }
    }

    func deleteArticle(_ article: FAQArticle) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await faqService.deleteArticle(articleId: article.id)
            showSuccessMessage("Artikel gelöscht")
            deselectArticle()
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Private Helpers

    func resetArticleForm() {
        editingArticle = nil
        newArticleTitle = ""
        newArticleSummary = ""
        newArticleContent = ""
        newArticleCategory = .general
        newArticleTags = []
        newArticleKeywords = []
    }

    func validateArticleForm() -> Bool {
        if newArticleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleError(FAQServiceError.invalidArticle("Titel darf nicht leer sein"))
            return false
        }

        if newArticleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleError(FAQServiceError.invalidArticle("Zusammenfassung darf nicht leer sein"))
            return false
        }

        if newArticleContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleError(FAQServiceError.invalidArticle("Inhalt darf nicht leer sein"))
            return false
        }

        return true
    }
}

// MARK: - Create from Ticket Extension

extension FAQKnowledgeBaseViewModel {
    /// Creates a new FAQ article from a resolved ticket
    func createArticleFromTicket(
        _ ticket: SupportTicket,
        solutionResponse: TicketResponse,
        category: KnowledgeBaseCategory,
        createdBy: String
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let article = try await faqService.createArticleFromTicket(
                ticket,
                solutionResponse: solutionResponse,
                category: category,
                createdBy: createdBy
            )
            showSuccessMessage("FAQ-Artikel '\(article.title)' aus Ticket erstellt")
            await load()
        } catch {
            handleError(error)
        }
    }

    /// Prepares form with data from a resolved ticket (for manual editing before creation)
    func prepareArticleFromTicket(_ ticket: SupportTicket, solutionResponse: TicketResponse) {
        let draftArticle = FAQArticle.fromResolvedTicket(
            ticket,
            solutionResponse: solutionResponse,
            category: .general,
            createdBy: ""
        )

        newArticleTitle = draftArticle.title
        newArticleSummary = draftArticle.summary
        newArticleContent = draftArticle.content
        newArticleCategory = draftArticle.category
        newArticleTags = draftArticle.tags
        newArticleKeywords = draftArticle.keywords
        showCreateArticleSheet = true
    }
}

