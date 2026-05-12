import Foundation
import UIKit

extension TradeStatementPDFServiceImproved {
    func drawHeader(
        in context: CGContext,
        trade: TradeOverviewItem,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let companyAttributes = PDFTextAttributesImproved.titleAttributes()
        PDFCompanyInfo.companyName.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: companyAttributes)
        y += PDFStylingImproved.titleFont.lineHeight + 12

        let detailsAttributes = PDFTextAttributesImproved.secondaryBodyAttributes()
        for detail in PDFCompanyInfo.companyDetails {
            detail.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: detailsAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 3
        }
        y += PDFStylingImproved.sectionSpacing

        "Collection Bill".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.headerAttributes()
        )
        y += PDFStylingImproved.headerFont.lineHeight + 8

        let tradeAttributes = PDFTextAttributesImproved.bodyAttributes()
        let tradeNumberText = "Trade #\(String(format: "%03d", trade.tradeNumber))"
        tradeNumberText.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: tradeAttributes)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "de_DE")
        let dateText = "Datum: \(dateFormatter.string(from: Date()))"
        let dateSize = dateText.size(withAttributes: tradeAttributes)
        dateText.draw(at: CGPoint(x: pageRect.width - PDFStylingImproved.margin - dateSize.width, y: y), withAttributes: tradeAttributes)
        return y + PDFStylingImproved.bodyFont.lineHeight + 8
    }

    func drawDepotInfo(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        "Depot-Informationen".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.subheaderAttributes()
        )
        y += PDFStylingImproved.subheaderFont.lineHeight + 12
        let bodyAttributes = PDFTextAttributesImproved.bodyAttributes()
        let depotInfo = [
            "Depotnummer: \(displayData.depotNumber)",
            "Depotinhaber: \(displayData.depotHolder)",
            "Wertpapier: \(displayData.securityIdentifier)",
            "Kontonummer: \(displayData.accountNumber)"
        ]
        for info in depotInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: bodyAttributes)
            y += PDFStylingImproved.bodyFont.lineHeight + 4
        }
        return y
    }

    func drawBuyTransaction(
        in context: CGContext,
        buyTransaction: BuyTransactionData,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        "Kauf-Transaktion".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.subheaderAttributes()
        )
        y += PDFStylingImproved.subheaderFont.lineHeight + 12
        let tableData = [
            ["Transaktionsnummer", buyTransaction.transactionNumber],
            ["Volumen", buyTransaction.orderVolume],
            ["Ausgeführtes Volumen", buyTransaction.executedVolume],
            ["Preis", buyTransaction.price],
            ["Marktwert", buyTransaction.marketValue],
            ["Provision", buyTransaction.commission],
            ["Eigene Kosten", buyTransaction.ownExpenses],
            ["Externe Kosten", buyTransaction.externalExpenses],
            ["Endbetrag", buyTransaction.finalAmount]
        ]
        return drawInfoTable(in: context, data: tableData, pageRect: pageRect, currentY: y)
    }

    func drawSellTransactions(
        in context: CGContext,
        sellTransactions: [SellTransactionData],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        "Verkauf-Transaktionen".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.subheaderAttributes()
        )
        y += PDFStylingImproved.subheaderFont.lineHeight + 12
        let contentWidth = PDFStylingImproved.contentWidth
        let columnWidths = PDFStylingImproved.sellTableColumnWidthRatios.map { contentWidth * $0 }
        let headerRect = CGRect(x: PDFStylingImproved.margin, y: y, width: contentWidth, height: PDFStylingImproved.tableHeaderHeight)
        context.setFillColor(PDFStylingImproved.tableHeaderBackgroundColor.cgColor)
        context.fill(headerRect)

        let headerTitles = ["Transaktionsnummer", "Volumen", "Preis", "Marktwert", "Provision", "Endbetrag"]
        let tableHeaderAttributes = PDFTextAttributesImproved.tableHeaderAttributes()
        var x = PDFStylingImproved.margin
        for (index, title) in headerTitles.enumerated() {
            let textRect = CGRect(
                x: x + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableHeaderHeight - PDFStylingImproved.tableHeaderFont.lineHeight) / 2,
                width: columnWidths[index] - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.tableHeaderFont.lineHeight
            )
            let attributedTitle = NSMutableAttributedString(string: title, attributes: tableHeaderAttributes)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = index == 0 ? .left : .right
            attributedTitle.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: title.count))
            attributedTitle.draw(in: textRect)
            x += columnWidths[index]
        }
        y += PDFStylingImproved.tableHeaderHeight

        let rowAttributes = PDFTextAttributesImproved.tableCellAttributes()
        for (index, transaction) in sellTransactions.enumerated() {
            let rowRect = CGRect(x: PDFStylingImproved.margin, y: y, width: contentWidth, height: PDFStylingImproved.tableRowHeight)
            if index % 2 == 0 {
                context.setFillColor(PDFStylingImproved.alternateRowBackgroundColor.cgColor)
                context.fill(rowRect)
            }
            context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
            context.setLineWidth(PDFStylingImproved.tableBorderWidth)
            context.stroke(rowRect)
            x = PDFStylingImproved.margin
            let rowData = [transaction.transactionNumber, transaction.orderVolume, transaction.price, transaction.marketValue, transaction.commission, transaction.finalAmount]
            for (colIndex, data) in rowData.enumerated() {
                let alignment: NSTextAlignment = colIndex == 0 ? .left : .right
                let cellRect = CGRect(
                    x: x + PDFStylingImproved.tableCellPadding,
                    y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.tableFont.lineHeight) / 2,
                    width: columnWidths[colIndex] - (PDFStylingImproved.tableCellPadding * 2),
                    height: PDFStylingImproved.tableFont.lineHeight
                )
                let attributedData = NSMutableAttributedString(string: data, attributes: rowAttributes)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                attributedData.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: data.count))
                attributedData.draw(in: cellRect)
                x += columnWidths[colIndex]
            }
            y += PDFStylingImproved.tableRowHeight
        }
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(PDFStylingImproved.tableBorderWidth * 2)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: PDFStylingImproved.margin + contentWidth, y: y))
        context.strokePath()
        return y
    }
}
