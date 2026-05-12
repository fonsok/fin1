import Foundation
import Combine
import os.log

// MARK: - FAQ Knowledge Base Service Implementation
/// Manages FAQ articles derived from resolved support tickets
/// Provides search, suggestions, and usage tracking

final class FAQKnowledgeBaseService: FAQKnowledgeBaseServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Properties

    let logger = Logger(subsystem: "com.fin.app", category: "FAQKnowledgeBase")
    let auditService: AuditLoggingServiceProtocol

    var articles: [FAQArticle] = []
    var feedbackStore: [FAQFeedback] = []
    var ticketArticleLinks: [String: [String]] = [:] // articleId -> [ticketIds]

    let articlesSubject = CurrentValueSubject<[FAQArticle], Never>([])

    var articlesPublisher: AnyPublisher<[FAQArticle], Never> {
        articlesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(auditService: AuditLoggingServiceProtocol) {
        self.auditService = auditService
        loadMockData()
    }

    // MARK: - ServiceLifecycle

    func start() {
        logger.info("FAQKnowledgeBaseService started")
    }

    func stop() {
        logger.info("FAQKnowledgeBaseService stopped")
    }

    func reset() {
        articles = []
        feedbackStore = []
        ticketArticleLinks = [:]
        articlesSubject.send([])
        loadMockData()
        logger.info("FAQKnowledgeBaseService reset")
    }

    // MARK: - Article Retrieval

    func getArticles(includeUnpublished: Bool, includeArchived: Bool) async throws -> [FAQArticle] {
        var result = articles

        if !includeUnpublished {
            result = result.filter { $0.isPublished }
        }

        if !includeArchived {
            result = result.filter { !$0.isArchived }
        }

        return result.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func getArticles(byCategory category: KnowledgeBaseCategory) async throws -> [FAQArticle] {
        return articles
            .filter { $0.category == category && $0.isPublished && !$0.isArchived }
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func getArticle(byId articleId: String) async throws -> FAQArticle? {
        return articles.first { $0.id == articleId }
    }

    func getPopularArticles(limit: Int) async throws -> [FAQArticle] {
        return articles
            .filter { $0.isPublished && !$0.isArchived }
            .sorted { $0.viewCount + ($0.usedInTicketCount * 5) > $1.viewCount + ($1.usedInTicketCount * 5) }
            .prefix(limit)
            .map { $0 }
    }

    func getRecentArticles(limit: Int) async throws -> [FAQArticle] {
        return articles
            .filter { $0.isPublished && !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }


    // MARK: - Article Management

    func createArticle(_ articleCreate: FAQArticleCreate, createdBy: String) async throws -> FAQArticle {
        // Check for duplicate title
        if articles.contains(where: { $0.title.lowercased() == articleCreate.title.lowercased() }) {
            throw FAQServiceError.duplicateTitle
        }

        let article = FAQArticle(
            title: articleCreate.title,
            summary: articleCreate.summary,
            content: articleCreate.content,
            category: articleCreate.category,
            tags: articleCreate.tags,
            keywords: articleCreate.keywords,
            sourceTicketIds: articleCreate.sourceTicketIds,
            solutionType: articleCreate.solutionType,
            relatedHelpCenterArticleId: articleCreate.relatedHelpCenterArticleId,
            createdBy: createdBy,
            isPublished: false
        )

        articles.append(article)
        articlesSubject.send(articles)

        logger.info("✅ FAQ article created: \(article.title)")
        return article
    }

    func createArticleFromTicket(
        _ ticket: SupportTicket,
        solutionResponse: TicketResponse,
        category: KnowledgeBaseCategory,
        createdBy: String
    ) async throws -> FAQArticle {
        let article = FAQArticle.fromResolvedTicket(
            ticket,
            solutionResponse: solutionResponse,
            category: category,
            createdBy: createdBy
        )

        articles.append(article)
        articlesSubject.send(articles)

        // Link ticket to article
        try await linkTicketToArticle(ticketId: ticket.id, articleId: article.id)

        logger.info("✅ FAQ article created from ticket \(ticket.ticketNumber): \(article.title)")
        return article
    }

    func updateArticle(articleId: String, update: FAQArticleUpdate, updatedBy: String) async throws -> FAQArticle {
        guard let index = articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        var article = articles[index]

        // Check for duplicate title if title is being updated
        if let newTitle = update.title,
           newTitle.lowercased() != article.title.lowercased(),
           articles.contains(where: { $0.title.lowercased() == newTitle.lowercased() && $0.id != articleId }) {
            throw FAQServiceError.duplicateTitle
        }

        // Apply updates - create new article with updated values
        let updatedTitle = update.title ?? article.title
        let updatedSummary = update.summary ?? article.summary
        let updatedContent = update.content ?? article.content
        let updatedCategory = update.category ?? article.category
        let updatedTags = update.tags ?? article.tags
        let updatedKeywords = update.keywords ?? article.keywords
        let updatedIsPublished = update.isPublished ?? article.isPublished

        article = FAQArticle(
            id: article.id,
            title: updatedTitle,
            summary: updatedSummary,
            content: updatedContent,
            category: updatedCategory,
            tags: updatedTags,
            keywords: updatedKeywords,
            sourceTicketIds: article.sourceTicketIds,
            solutionType: article.solutionType,
            relatedHelpCenterArticleId: article.relatedHelpCenterArticleId,
            viewCount: article.viewCount,
            helpfulCount: article.helpfulCount,
            notHelpfulCount: article.notHelpfulCount,
            usedInTicketCount: article.usedInTicketCount,
            createdAt: article.createdAt,
            updatedAt: Date(),
            createdBy: article.createdBy,
            lastUpdatedBy: updatedBy,
            isPublished: updatedIsPublished,
            isArchived: article.isArchived
        )

        articles[index] = article
        articlesSubject.send(articles)

        logger.info("✏️ FAQ article updated: \(article.title)")
        return article
    }

    func publishArticle(articleId: String) async throws {
        guard let index = self.articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        let articleTitle = articles[index].title
        articles[index].isPublished = true
        articles[index].updatedAt = Date()
        articlesSubject.send(articles)

        logger.info("📢 FAQ article published: \(articleTitle)")
    }

    func unpublishArticle(articleId: String) async throws {
        guard let index = self.articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        let articleTitle = articles[index].title
        articles[index].isPublished = false
        articles[index].updatedAt = Date()
        articlesSubject.send(articles)

        logger.info("📝 FAQ article unpublished: \(articleTitle)")
    }

    func archiveArticle(articleId: String) async throws {
        guard let index = self.articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        let articleTitle = articles[index].title
        articles[index].isArchived = true
        articles[index].isPublished = false
        articles[index].updatedAt = Date()
        articlesSubject.send(articles)

        logger.info("📦 FAQ article archived: \(articleTitle)")
    }

    func deleteArticle(articleId: String) async throws {
        guard let index = articles.firstIndex(where: { $0.id == articleId }) else {
            throw FAQServiceError.articleNotFound
        }

        let title = articles[index].title
        articles.remove(at: index)
        ticketArticleLinks.removeValue(forKey: articleId)
        articlesSubject.send(articles)

        logger.info("🗑️ FAQ article deleted: \(title)")
    }


    // MARK: - Mock Data

    private func loadMockData() {
        articles = Self.createMockArticles()
        articlesSubject.send(articles)
    }

    static func createMockArticles() -> [FAQArticle] {
        [
            FAQArticle(
                title: "Wie setze ich mein Passwort zurück?",
                summary: "Anleitung zum Zurücksetzen des Passworts bei vergessenem Zugang",
                content: """
                ## Problem
                Sie haben Ihr Passwort vergessen und können sich nicht mehr einloggen.

                ## Lösung
                1. Öffnen Sie die \(AppBrand.appName) App oder Website
                2. Klicken Sie auf "Passwort vergessen?"
                3. Geben Sie Ihre registrierte E-Mail-Adresse ein
                4. Prüfen Sie Ihr E-Mail-Postfach (inkl. Spam-Ordner)
                5. Klicken Sie auf den Link in der E-Mail
                6. Erstellen Sie ein neues sicheres Passwort

                ## Hinweise
                - Der Link ist 24 Stunden gültig
                - Verwenden Sie mindestens 8 Zeichen mit Groß- und Kleinbuchstaben
                - Falls Sie keine E-Mail erhalten, kontaktieren Sie den Support
                """,
                category: .login,
                tags: ["Passwort", "Login", "Zugang"],
                keywords: ["passwort", "vergessen", "zurücksetzen", "reset", "login", "zugang"],
                viewCount: 1250,
                helpfulCount: 180,
                notHelpfulCount: 12,
                usedInTicketCount: 45,
                createdBy: "system"
            ),
            FAQArticle(
                title: "Warum kann ich mich nicht einloggen?",
                summary: "Häufige Ursachen und Lösungen für Login-Probleme",
                content: """
                ## Problem
                Der Login schlägt fehl oder zeigt eine Fehlermeldung.

                ## Mögliche Ursachen & Lösungen

                ### 1. Falsche Anmeldedaten
                - Prüfen Sie die korrekte Schreibweise von E-Mail und Passwort
                - Achten Sie auf Groß-/Kleinschreibung beim Passwort
                - Nutzen Sie "Passwort vergessen?" falls nötig

                ### 2. Konto gesperrt
                - Nach 5 fehlgeschlagenen Versuchen wird das Konto temporär gesperrt
                - Warten Sie 15 Minuten oder kontaktieren Sie den Support

                ### 3. App veraltet
                - Aktualisieren Sie die App auf die neueste Version
                - iOS: App Store → Updates
                - Android: Play Store → Meine Apps

                ### 4. Cache-Problem
                - Schließen Sie die App vollständig
                - Löschen Sie den App-Cache (Einstellungen → Apps → \(AppBrand.appName) → Cache leeren)
                - Starten Sie die App neu
                """,
                category: .login,
                tags: ["Login", "Fehler", "Anmeldung"],
                keywords: ["login", "anmelden", "fehler", "problem", "gesperrt", "konto"],
                viewCount: 890,
                helpfulCount: 145,
                notHelpfulCount: 8,
                usedInTicketCount: 38,
                createdBy: "system"
            ),
            FAQArticle(
                title: "Wie tätige ich meine erste Investition?",
                summary: "Schritt-für-Schritt Anleitung für Ihre erste Investition",
                content: """
                ## Voraussetzungen
                - Konto vollständig verifiziert (KYC abgeschlossen)
                - Guthaben auf dem Konto

                ## Anleitung

                ### 1. Trader auswählen
                - Gehen Sie zur Trader-Übersicht
                - Analysieren Sie Performance und Risikoprofil
                - Wählen Sie einen Trader, der zu Ihren Zielen passt

                ### 2. Investitionsbetrag festlegen
                - Tippen Sie auf "Investieren"
                - Geben Sie den gewünschten Betrag ein
                - Beachten Sie den Mindestbetrag (100€)

                ### 3. Bestätigung
                - Prüfen Sie die Zusammenfassung
                - Akzeptieren Sie die Bedingungen
                - Bestätigen Sie die Investition

                ### 4. Nachverfolgung
                - Verfolgen Sie Ihre Investition unter Investments
                - Sie erhalten Benachrichtigungen bei wichtigen Ereignissen
                """,
                category: .investment,
                tags: ["Investment", "Erste Schritte", "Anleitung"],
                keywords: ["investieren", "erste", "anleitung", "trader", "betrag", "investments"],
                viewCount: 720,
                helpfulCount: 112,
                notHelpfulCount: 5,
                usedInTicketCount: 22,
                createdBy: "system"
            ),
            FAQArticle(
                title: "Welche Gebühren fallen an?",
                summary: "Übersicht aller Gebühren und Kosten bei \(AppBrand.appName)",
                content: """
                ## Gebührenübersicht

                ### Depotführung
                - Keine Grundgebühr für das Depot

                ### Trading-Gebühren
                - Ordergebühr: 0,25% des Handelsvolumens
                - Mindestgebühr: 4,90€ pro Order
                - Maximale Gebühr: 59,90€ pro Order

                ### Börsengebühren
                - Xetra: 0,01% (min. 1,50€)
                - Frankfurt: 0,015% (min. 2,00€)
                - NYSE/NASDAQ: 0,02% (min. 2,50€)

                ### Investorengebühren
                - Performance Fee: 20% auf realisierte Gewinne
                - Keine Gebühr bei Verlusten

                ### Ein- und Auszahlungen
                - Einzahlung per Überweisung: kostenlos
                - Auszahlung: kostenlos (1x monatlich, danach 2€)

                ## Hinweis
                Alle Gebühren werden transparent vor jeder Transaktion angezeigt.
                """,
                category: .payment,
                tags: ["Gebühren", "Kosten", "Preise"],
                keywords: ["gebühren", "kosten", "preise", "fee", "order", "trading"],
                viewCount: 650,
                helpfulCount: 98,
                notHelpfulCount: 7,
                usedInTicketCount: 18,
                createdBy: "system"
            ),
            FAQArticle(
                title: "App stürzt beim Start ab",
                summary: "Lösung für App-Abstürze und Stabilitätsprobleme",
                content: """
                ## Problem
                Die App stürzt beim Start ab oder friert ein.

                ## Schnelle Lösungen

                ### 1. Neustart erzwingen
                - Schließen Sie die App vollständig
                - iOS: Doppelklick Home-Button, App nach oben wischen
                - Android: Kürzlich verwendete Apps, App schließen

                ### 2. Cache leeren
                - Geräte-Einstellungen → Apps → \(AppBrand.appName) → Cache leeren
                - Gerät neu starten

                ### 3. App aktualisieren
                - Prüfen Sie auf Updates im App Store / Play Store
                - Installieren Sie die neueste Version

                ### 4. App neu installieren
                - App deinstallieren
                - Gerät neu starten
                - App neu installieren
                - Mit Ihren Zugangsdaten anmelden

                ## Wichtig
                Ihre Daten sind sicher in der Cloud gespeichert und gehen durch eine Neuinstallation nicht verloren.
                """,
                category: .technical,
                tags: ["App", "Absturz", "Technisch"],
                keywords: ["absturz", "crash", "app", "start", "einfrieren", "problem"],
                viewCount: 580,
                helpfulCount: 88,
                notHelpfulCount: 12,
                usedInTicketCount: 28,
                createdBy: "system"
            ),
            FAQArticle(
                title: "Wie ändere ich meine Adresse?",
                summary: "Anleitung zur Adressänderung im Konto",
                content: """
                ## Vorgehensweise

                ### Online-Änderung
                1. Melden Sie sich in der App an
                2. Gehen Sie zu Einstellungen → Persönliche Daten
                3. Tippen Sie auf "Adresse ändern"
                4. Geben Sie Ihre neue Adresse ein
                5. Laden Sie einen Nachweis hoch (Meldebescheinigung oder Rechnung)

                ### Bearbeitung
                - Die Prüfung dauert in der Regel 1-2 Werktage
                - Sie erhalten eine Bestätigung per E-Mail

                ### Akzeptierte Nachweise
                - Aktuelle Meldebescheinigung
                - Stromrechnung (max. 3 Monate alt)
                - Telefonrechnung (max. 3 Monate alt)
                - Kontoauszug (max. 3 Monate alt)

                ## Wichtig
                Die Adresse muss mit Ihrem Ausweisdokument übereinstimmen.
                """,
                category: .account,
                tags: ["Adresse", "Änderung", "Konto"],
                keywords: ["adresse", "ändern", "umzug", "wohnung", "anschrift"],
                viewCount: 320,
                helpfulCount: 52,
                notHelpfulCount: 3,
                usedInTicketCount: 12,
                createdBy: "system"
            )
        ]
    }
}

