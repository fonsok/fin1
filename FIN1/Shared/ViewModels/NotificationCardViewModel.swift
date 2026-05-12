import Foundation
import Combine

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
        notificationService.markAsRead(notification)

        switch NotificationMetadataActionResolver.resolve(for: notification) {
        case .survey(let surveyRequestId):
            await loadAndShowSurvey(surveyRequestId: surveyRequestId)
        case .ticket(let ticketId):
            await loadAndShowTicket(ticketId: ticketId)
        case .document(let documentId):
            await loadAndShowDocument(documentId: documentId)
        case .none:
            break
        }
    }

    func dismissSurvey() {
        showSurvey = false
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
            _ = try await satisfactionSurveyService.submitSurvey(
                surveyRequestId: requestId,
                rating: rating,
                wasIssueResolved: issueResolved,
                wasAgentHelpful: agentHelpful,
                wasResponseTimeSatisfactory: responseTimeSatisfactory,
                comment: comment
            )
        } catch {
            errorMessage = "Fehler beim Senden des Feedbacks: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func loadAndShowSurvey(surveyRequestId: String) async {
        isLoadingTicket = true
        showErrorAlert = false
        showSurvey = false
        surveyRequest = nil

        do {
            if let request = try await satisfactionSurveyService.getSurveyRequest(id: surveyRequestId) {
                surveyRequest = request

                if !request.isCompleted && !request.isExpired {
                    showSurvey = true
                } else {
                    errorMessage = request.isExpired ? "Diese Umfrage ist abgelaufen." : "Diese Umfrage wurde bereits ausgefüllt."
                    showErrorAlert = true
                }
            } else {
                errorMessage = "Die Umfrage konnte nicht gefunden werden."
                showErrorAlert = true
            }
        } catch {
            errorMessage = "Die Umfrage konnte nicht geladen werden: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isLoadingTicket = false
    }

    private func loadAndShowTicket(ticketId: String) async {
        isLoadingTicket = true
        showErrorAlert = false
        showTicketDetail = false
        ticket = nil

        do {
            if let loadedTicket = try await customerSupportService.getTicket(ticketId: ticketId) {
                ticket = loadedTicket
                showTicketDetail = true
            } else {
                errorMessage = "Das Ticket konnte nicht gefunden werden. Bitte versuchen Sie es später erneut."
                showErrorAlert = true
            }
        } catch {
            // Provide user-friendly error message
            if let nsError = error as NSError? {
                if nsError.domain == NSURLErrorDomain {
                    errorMessage = "Verbindungsfehler. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut."
                } else {
                    errorMessage = "Das Ticket konnte nicht geladen werden: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Das Ticket konnte nicht geladen werden. Bitte versuchen Sie es später erneut."
            }
            showErrorAlert = true
        }

        isLoadingTicket = false
    }

    private func loadAndShowDocument(documentId: String) async {
        isLoadingTicket = true
        showErrorAlert = false
        sheetDocument = nil

        do {
            let document = try await documentService.resolveDocumentForDeepLink(objectId: documentId)
            documentService.markDocumentAsRead(document)
            sheetDocument = document
        } catch let error as DocumentDeepLinkResolveError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
                errorMessage = "Verbindungsfehler. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut."
            } else {
                errorMessage = "Das Dokument konnte nicht geladen werden: \(error.localizedDescription)"
            }
            showErrorAlert = true
        }

        isLoadingTicket = false
    }
}

