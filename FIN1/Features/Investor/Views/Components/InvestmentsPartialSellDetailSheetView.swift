import SwiftUI

struct InvestmentsPartialSellDetailSheetView: View {
    let investment: Investment
    let appServices: AppServices
    let partialSellSheetMirrorSummary: ServerInvestmentCanonicalSummary?
    let partialSellSheetCollectionBills: [BackendCollectionBill]
    let partialSellSheetServerLoading: Bool
    let onDone: () -> Void

    private static let billDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var collectionBillRef: String? {
        let investmentDocuments = self.appServices.documentService.getDocumentsForInvestment(self.investment.id)
        return investmentDocuments
            .first(where: { $0.type == .investorCollectionBill })?
            .accountingDocumentNumber
    }

    private var commissionRef: String? {
        let investmentDocuments = self.appServices.documentService.getDocumentsForInvestment(self.investment.id)
        return investmentDocuments
            .first(where: { $0.type == .traderCreditNote })?
            .accountingDocumentNumber
    }

    private var serviceChargeInvoiceRef: String? {
        let currentUserId = self.appServices.userService.currentUser?.id ?? ""
        return self.investment.batchId.flatMap {
            self.appServices.invoiceService.getServiceChargeInvoiceForBatch($0, userId: currentUserId)?.invoiceNumber
        }
    }

    private var sortedBills: [BackendCollectionBill] {
        self.partialSellSheetCollectionBills.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    Text("Investment \(self.investment.canonicalDisplayReference)")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("Teil-Sells: \(self.investment.partialSellCount)")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    if let tradePct = investment.tradeSellVolumeProgressPercent {
                        Text("Trade (Stück, kumulativ): \(tradePct.formatted(.number.precision(.fractionLength(1))))% verkauft")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                    }

                    Text(
                        "Bruttoerlös / Einlage: \(self.investment.realizedSellSharePercentage.formatted(.number.precision(.fractionLength(1))))%"
                    )
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                    Text("Realisierter Betrag (Pool-Anteil Verkauf): \(self.investment.realizedSellAmount.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("Letzter Teil-Sell: \(self.formattedPartialSellDate(self.investment.lastPartialSellAt))")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Divider()

                    Text("Mirror-Handel / P&L (Collection Bills, Server)")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(
                        "Kumuliert aus allen gültigen Investor-Collection-Bills (inkl. Teil-Sell-Deltas). Entspricht den GoB-Belegen inkl. buyLeg/sellLeg-Metadaten."
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)

                    self.mirrorSummaryBlock

                    Divider()

                    Text("Belegliste (GoB, Server)")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    self.billsBlock

                    Divider()

                    Text("Weitere Nachweise (lokal / andere Belegarten)")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("Collection Bill (lokal, erste Kachel): \(self.collectionBillRef ?? "kein lokaler Eintrag")")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Text("Commission-/Credit-Note Beleg: \(self.commissionRef ?? "noch nicht vorhanden")")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Text("Service-Charge Rechnung: \(self.serviceChargeInvoiceRef ?? "nicht zutreffend/noch nicht vorhanden")")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Text(
                        "Hinweis: „Trade (Stück)“ und „Bruttoerlös/Einlage“ beziehen sich auf Pool-Anteile am Trade. Mirror-P&L stammt aus den gleichen Collection Bills wie die Buchhaltung (Teil-Sell: `bookInvestorPartialRealizationDeltaIfAny`). Abschluss-Belege kommen bei Trade-Completion hinzu."
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)
                }
                .padding(ResponsiveDesign.horizontalPadding())
                .padding(.bottom, ResponsiveDesign.spacing(24))
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Teil-Sell Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig", action: self.onDone)
                }
            }
        }
    }

    @ViewBuilder
    private var mirrorSummaryBlock: some View {
        if self.partialSellSheetServerLoading {
            ProgressView()
                .padding(.vertical, ResponsiveDesign.spacing(8))
        } else if let mirror = partialSellSheetMirrorSummary {
            Text("Bruttoergebnis (Σ): \(mirror.grossProfit.formattedAsLocalizedCurrency())")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Provision (Σ): \(mirror.commission.formattedAsLocalizedCurrency())")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Netto (Σ): \(mirror.netProfit.formattedAsLocalizedCurrency())")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Text("Mirror-Basis gesamt (Σ Kauf-Seite): \(mirror.totalBuyCost.formattedAsLocalizedCurrency())")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
            if mirror.hasReturnPercentage {
                Text(
                    "Gewichtete Rendite (aus Beleg-Metadaten): \(mirror.returnPercentage.formatted(.number.precision(.fractionLength(2))))%"
                )
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
            }
            Text("Anzahl einbezogener Bills: \(mirror.billCount)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.tertiaryText)
        } else if self.partialSellSheetCollectionBills.isEmpty && self.appServices.settlementAPIService != nil {
            Text(
                "Keine Collection Bills auf dem Server für dieses Investment — Teil-Sell-Abrechnung wurde noch nicht verbucht oder Daten sind nicht geladen."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.tertiaryText)
        } else if self.partialSellSheetCollectionBills.isEmpty {
            Text("Settlement-API nicht verfügbar — P&L aus Belegen kann nicht geladen werden.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.tertiaryText)
        } else {
            Text(
                "Collection Bills vorhanden, aber ohne kanonische Rendite-Metadaten — Bitte Admin-Audit „auditCollectionBillReturnPercentage“ prüfen."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.tertiaryText)
        }
    }

    @ViewBuilder
    private var billsBlock: some View {
        if self.sortedBills.isEmpty && !self.partialSellSheetServerLoading {
            Text("Keine Einträge.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.tertiaryText)
        } else {
            ForEach(self.sortedBills, id: \.objectId) { bill in
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(bill.accountingDocumentNumber ?? "—")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                    if let tn = bill.tradeNumber {
                        Text("Trade #\(tn)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    if let meta = bill.metadata {
                        let gross = meta.grossProfit ?? 0
                        let net = meta.netProfit ?? ((meta.grossProfit ?? 0) - (meta.commission ?? 0))
                        Text("Brutto \(gross.formattedAsLocalizedCurrency()) · Netto \(net.formattedAsLocalizedCurrency())")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Text(self.formattedBackendBillDate(bill.createdAt))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                    Divider()
                }
                .padding(.vertical, ResponsiveDesign.spacing(4))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func formattedPartialSellDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedBackendBillDate(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        if let date = Self.billDateFormatter.date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return String(iso.prefix(16))
    }
}
