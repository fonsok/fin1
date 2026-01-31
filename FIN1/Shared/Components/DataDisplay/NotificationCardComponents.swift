import SwiftUI

// Extension to make Int Identifiable for sheet presentation
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Unified Item Card
struct UnifiedItemCard: View {
    let item: NotificationItem
    @ObservedObject var notificationService: NotificationService
    @Environment(\.appServices) private var appServices

    var body: some View {
        switch item {
        case .notification(let notification):
            NotificationCardView(notification: notification, notificationService: notificationService)
        case .document(let document):
            DocumentCardView(document: document)
        }
    }
}

// MARK: - Notification Card View
struct NotificationCardView: View {
    let notification: AppNotification
    @ObservedObject var notificationService: NotificationService
    @Environment(\.appServices) private var appServices
    @State private var showTicketDetail = false
    @State private var showSurvey = false
    @State private var ticket: SupportTicket?
    @State private var surveyRequest: SurveyRequest?
    @State private var isLoadingTicket = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        Button(action: {
            notificationService.markAsRead(notification)
            // Check if this is a survey notification
            if let surveyRequestId = notification.metadata?["surveyRequestId"] {
                Task {
                    await loadAndShowSurvey(surveyRequestId: surveyRequestId)
                }
            }
            // Check if this is a ticket notification
            else if let ticketId = notification.metadata?["ticketId"] {
                Task {
                    await loadAndShowTicket(ticketId: ticketId)
                }
            }
        }) {
            ZStack {
                HStack(spacing: ResponsiveDesign.spacing(16)) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(notificationColor)
                    .frame(width: 40, height: 40)
                    .background(notificationColor.opacity(0.1))
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(notification.title)
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        // Unread indicator
                        if notification.isRead {
                            Circle()
                                .fill(AppTheme.accentLightBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(notification.message)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(notification.createdAt, style: .date)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                            .textCase(.uppercase)

                        Spacer()

                        if notification.priority == .high || notification.priority == .urgent {
                            Text("Tap to view")
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.accentLightBlue)
                                .padding(.horizontal, ResponsiveDesign.spacing(8))
                                .padding(.vertical, ResponsiveDesign.spacing(4))
                                .background(AppTheme.accentLightBlue.opacity(0.1))
                                .cornerRadius(ResponsiveDesign.spacing(6))
                        }
                    }
                }
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .opacity(notification.isRead ? 0.7 : 1.0)

                // Loading overlay
                if isLoadingTicket {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.sectionBackground.opacity(0.8))
                        .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoadingTicket)
        .sheet(isPresented: $showTicketDetail) {
            if let ticket = ticket {
                UserTicketDetailView(
                    ticket: ticket,
                    userId: appServices.userService.currentUser?.id ?? "",
                    supportService: appServices.customerSupportService
                )
            }
        }
        .sheet(isPresented: $showSurvey) {
            if let request = surveyRequest {
                SatisfactionSurveyView(
                    surveyRequest: request,
                    onSubmit: { rating, issueResolved, agentHelpful, responseTimeSatisfactory, comment in
                        await submitSurvey(
                            requestId: request.id,
                            rating: rating,
                            issueResolved: issueResolved,
                            agentHelpful: agentHelpful,
                            responseTimeSatisfactory: responseTimeSatisfactory,
                            comment: comment
                        )
                    },
                    onDismiss: { showSurvey = false }
                )
            }
        }
        .alert("Fehler", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadAndShowSurvey(surveyRequestId: String) async {
        await MainActor.run {
            isLoadingTicket = true
            showErrorAlert = false
        }

        do {
            if let request = try await appServices.satisfactionSurveyService.getSurveyRequest(id: surveyRequestId) {
                await MainActor.run {
                    self.surveyRequest = request
                    self.isLoadingTicket = false
                    if !request.isCompleted && !request.isExpired {
                        self.showSurvey = true
                    } else {
                        self.errorMessage = request.isExpired ? "Diese Umfrage ist abgelaufen." : "Diese Umfrage wurde bereits ausgefüllt."
                        self.showErrorAlert = true
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoadingTicket = false
                    self.errorMessage = "Die Umfrage konnte nicht gefunden werden."
                    self.showErrorAlert = true
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingTicket = false
                self.errorMessage = "Die Umfrage konnte nicht geladen werden: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }

    private func submitSurvey(
        requestId: String,
        rating: Int,
        issueResolved: Bool,
        agentHelpful: Bool,
        responseTimeSatisfactory: Bool,
        comment: String?
    ) async {
        do {
            _ = try await appServices.satisfactionSurveyService.submitSurvey(
                surveyRequestId: requestId,
                rating: rating,
                wasIssueResolved: issueResolved,
                wasAgentHelpful: agentHelpful,
                wasResponseTimeSatisfactory: responseTimeSatisfactory,
                comment: comment
            )
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Senden des Feedbacks: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }

    private func loadAndShowTicket(ticketId: String) async {
        await MainActor.run {
            isLoadingTicket = true
            showErrorAlert = false
        }

        do {
            if let loadedTicket = try await appServices.customerSupportService.getTicket(ticketId: ticketId) {
                await MainActor.run {
                    self.ticket = loadedTicket
                    self.isLoadingTicket = false
                    self.showTicketDetail = true
                }
            } else {
                await MainActor.run {
                    self.isLoadingTicket = false
                    self.errorMessage = "Das Ticket konnte nicht gefunden werden. Bitte versuchen Sie es später erneut."
                    self.showErrorAlert = true
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingTicket = false
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
        }
    }

    private var notificationColor: Color {
        switch notification.type {
        case .investment:
            return AppTheme.accentGreen
        case .trader:
            return AppTheme.accentLightBlue
        case .system:
            return AppTheme.accentOrange
        case .document:
            return AppTheme.accentOrange
        case .security:
            return AppTheme.accentRed
        case .marketing:
            return AppTheme.accentLightBlue
        }
    }
}

// MARK: - Document Card View
// Extracted to DocumentCardView.swift for file size compliance
