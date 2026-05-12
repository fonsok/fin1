import SwiftUI

/// Lädt einen Parse-`Document`-Beleg per `objectId` — typischerweise für Admin am App-Ledger.
///
/// Versucht zuerst den lokalen `DocumentService`-Cache, fällt dann auf die admin-tauglichen
/// Cloud Functions (`searchDocuments` / `getDocumentByObjectId`) zurück. So funktioniert die
/// Auflösung auch dann, wenn das Dokument einem anderen User gehört (Admin-Sicht) und
/// damit per Standard-ACL nicht über `fetchObject` erreichbar wäre.
struct AppLedgerDocumentDetailView: View {
    let documentObjectId: String
    @Environment(\.appServices) private var services
    @State private var document: Document?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let document {
                DocumentNavigationHelper.navigationDestination(for: document, appServices: services)
            } else if let loadError {
                Text(loadError)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ProgressView("Beleg wird geladen …")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard document == nil, loadError == nil else { return }

        if let cached = services.documentService.getDocument(by: documentObjectId) {
            document = cached
            return
        }

        if let parseAPIClient = services.parseAPIClient {
            let admin = DocumentSearchAPIService(parseAPIClient: parseAPIClient)
            do {
                document = try await admin.loadFullDocument(objectId: documentObjectId)
                return
            } catch {
                // Admin-Pfad fehlgeschlagen — versuche User-Sicht (eigene Belege)
            }
        }

        do {
            document = try await services.documentService.resolveDocumentForDeepLink(objectId: documentObjectId)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Backwards-compatible alias, da die Reservierungs-Eigenbeleg-Detailansicht historisch
/// einen sprechenderen Namen hatte.
typealias AppLedgerReservationEigenbelegDetailView = AppLedgerDocumentDetailView
