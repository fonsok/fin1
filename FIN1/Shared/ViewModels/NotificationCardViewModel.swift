import Combine
import Foundation

@MainActor
final class NotificationCardViewModel: ObservableObject {
    let notification: AppNotification

    private let notificationService: any NotificationServiceProtocol
    private let customerSupportService: any CustomerSupportServiceProtocol
    private let satisfactionSurveyService: any SatisfactionSurveyServiceProtocol
    private let documentService: any DocumentServiceProtocol

    // UI state
    @Published var showTicketDetail = false
    @Published var showSurvey = false
    @Published var sheetDocument: Document?
    @Published var ticket: SupportTicket?
    @Published var surveyRequest: SurveyRequest?
    @Published var isLoadingTicket = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

    init(
        notification: AppNotification,
        notificationService: any NotificationServiceProtocol,
        customerSupportService: any CustomerSupportServiceProtocol,
        satisfactionSurveyService: any SatisfactionSurveyServiceProtocol,
        documentService: any DocumentServiceProtocol
    ) {
        self.notification = notification
        self.notificationService = notificationService
        self.customerSupportService = customerSupportService
        self.satisfactionSurveyService = satisfactionSurveyService
        self.documentService = documentService
    }

    func handlePrimaryTap() async {
        self.notificationService.markAsRead(self.notification)

        switch NotificationMetadataActionResolver.resolve(for: self.notification) {
        case .survey(let surveyRequestId):
            await self.loadAndShowSurvey(surveyRequestId: surveyRequestId)
        case .ticket(let ticketId):
            await self.loadAndShowTicket(ticketId: ticketId)
        case .document(let documentId):
            await self.loadAndShowDocument(documentId: documentId)
        case .none:
            break
        }
    }

    func dismissSurvey() {
        self.showSurvey = false
    }

    func submitSurvey(
        requestId: String,
        rating: Int,
        issueResolved: Bool,
        agentHelpful: Bool,
        responseTimeSatisfactory: Bool,
        comment: String?
    ) async {
        do {
            _ = try await self.satisfactionSurveyService.submitSurvey(
                surveyRequestId: requestId,
                rating: rating,
                wasIssueResolved: issueResolved,
                wasAgentHelpful: agentHelpful,
                wasResponseTimeSatisfactory: responseTimeSatisfactory,
                comment: comment
            )
        } catch {
            self.errorMessage = "Fehler beim Senden des Feedbacks: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
    }

    private func loadAndShowSurvey(surveyRequestId: String) async {
        self.isLoadingTicket = true
        self.showErrorAlert = false
        self.showSurvey = false
        self.surveyRequest = nil

        do {
            if let request = try await satisfactionSurveyService.getSurveyRequest(id: surveyRequestId) {
                self.surveyRequest = request

                if !request.isCompleted && !request.isExpired {
                    self.showSurvey = true
                } else {
                    self.errorMessage = request.isExpired ? "Diese Umfrage ist abgelaufen." : "Diese Umfrage wurde bereits ausgefüllt."
                    self.showErrorAlert = true
                }
            } else {
                self.errorMessage = "Die Umfrage konnte nicht gefunden werden."
                self.showErrorAlert = true
            }
        } catch {
            self.errorMessage = "Die Umfrage konnte nicht geladen werden: \(error.localizedDescription)"
            self.showErrorAlert = true
        }

        self.isLoadingTicket = false
    }

    private func loadAndShowTicket(ticketId: String) async {
        self.isLoadingTicket = true
        self.showErrorAlert = false
        self.showTicketDetail = false
        self.ticket = nil

        do {
            if let loadedTicket = try await customerSupportService.getTicket(ticketId: ticketId) {
                self.ticket = loadedTicket
                self.showTicketDetail = true
            } else {
                self.errorMessage = "Das Ticket konnte nicht gefunden werden. Bitte versuchen Sie es später erneut."
                self.showErrorAlert = true
            }
        } catch {
            // Provide user-friendly error message
            if let nsError = error as NSError? {
                if nsError.domain == NSURLErrorDomain {
                    self.errorMessage = "Verbindungsfehler. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut."
                } else {
                    self.errorMessage = "Das Ticket konnte nicht geladen werden: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "Das Ticket konnte nicht geladen werden. Bitte versuchen Sie es später erneut."
            }
            self.showErrorAlert = true
        }

        self.isLoadingTicket = false
    }

    private func loadAndShowDocument(documentId: String) async {
        self.isLoadingTicket = true
        self.showErrorAlert = false
        self.sheetDocument = nil

        do {
            let document = try await documentService.resolveDocumentForDeepLink(objectId: documentId)
            self.documentService.markDocumentAsRead(document)
            self.sheetDocument = document
        } catch let error as DocumentDeepLinkResolveError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
                self.errorMessage = "Verbindungsfehler. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut."
            } else {
                self.errorMessage = "Das Dokument konnte nicht geladen werden: \(error.localizedDescription)"
            }
            self.showErrorAlert = true
        }

        self.isLoadingTicket = false
    }
}

