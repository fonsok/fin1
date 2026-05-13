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
                DocumentNavigationHelper.navigationDestination(for: document, appServices: self.services)
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
            await self.loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard self.document == nil, self.loadError == nil else { return }

        if let cached = services.documentService.getDocument(by: documentObjectId) {
            self.document = cached
            return
        }

        if let parseAPIClient = services.parseAPIClient {
            let admin = DocumentSearchAPIService(parseAPIClient: parseAPIClient)
            do {
                self.document = try await admin.loadFullDocument(objectId: self.documentObjectId)
                return
            } catch {
                // Admin-Pfad fehlgeschlagen — versuche User-Sicht (eigene Belege)
            }
        }

        do {
            self.document = try await self.services.documentService.resolveDocumentForDeepLink(objectId: self.documentObjectId)
        } catch {
            self.loadError = error.localizedDescription
        }
    }
}

/// Backwards-compatible alias, da die Reservierungs-Eigenbeleg-Detailansicht historisch
/// einen sprechenderen Namen hatte.
typealias AppLedgerReservationEigenbelegDetailView = AppLedgerDocumentDetailView
