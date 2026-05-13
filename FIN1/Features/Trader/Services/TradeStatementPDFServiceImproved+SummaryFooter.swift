import Foundation
import UIKit

extension TradeStatementPDFServiceImproved {
    func drawCalculationBreakdown(
        in context: CGContext,
        calculationBreakdown: CalculationBreakdownData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        "Berechnungsübersicht".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.subheaderAttributes()
        )
        y += PDFStylingImproved.subheaderFont.lineHeight + 12
        let tableData = [
            ["Gesamt-Verkaufsbetrag", calculationBreakdown.totalSellAmount],
            ["Kaufbetrag", calculationBreakdown.buyAmount],
            ["Ergebnis vor Steuern", calculationBreakdown.resultBeforeTaxes]
        ]
        return self.drawInfoTable(in: context, data: tableData, pageRect: pageRect, currentY: y)
    }

    func drawTaxSummary(
        in context: CGContext,
        taxSummary: TaxSummaryData,
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + 15
        "Steuerübersicht".draw(
            at: CGPoint(x: PDFStylingImproved.margin, y: y),
            withAttributes: PDFTextAttributesImproved.subheaderAttributes()
        )
        y += PDFStylingImproved.subheaderFont.lineHeight + 12

        let totalsX = pageRect.width - PDFStylingImproved.margin - PDFStylingImproved.totalsWidth
        let totalsAttributes = PDFTextAttributesImproved.totalsAttributes()
        let assessmentText = "Bemessungsgrundlage:"
        let assessmentValue = taxSummary.assessmentBasis
        let assessmentSize = assessmentText.size(withAttributes: totalsAttributes)
        assessmentText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        assessmentValue.draw(at: CGPoint(x: totalsX + assessmentSize.width + 10, y: y), withAttributes: totalsAttributes)
        y += 22

        let taxText = "Gesamtsteuer:"
        let taxValue = taxSummary.totalTax
        let taxSize = taxText.size(withAttributes: totalsAttributes)
        taxText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        taxValue.draw(at: CGPoint(x: totalsX + taxSize.width + 10, y: y), withAttributes: totalsAttributes)
        y += 22

        let netText = "Nettoergebnis:"
        let netValue = taxSummary.netResult
        let netTextSize = netText.size(withAttributes: totalsAttributes)
        netText.draw(at: CGPoint(x: totalsX, y: y), withAttributes: totalsAttributes)
        var netValueAttributes = totalsAttributes
        netValueAttributes[.font] = PDFStylingImproved.headerFont
        netValueAttributes[.foregroundColor] = PDFStylingImproved.primaryColor
        netValue.draw(at: CGPoint(x: totalsX + netTextSize.width + 10, y: y), withAttributes: netValueAttributes)
        y += 20
        context.setStrokeColor(PDFStylingImproved.primaryColor.cgColor)
        context.setLineWidth(1.5)
        let underlineX = totalsX + netTextSize.width + 10
        let underlineWidth = netValue.size(withAttributes: netValueAttributes).width
        context.move(to: CGPoint(x: underlineX, y: y))
        context.addLine(to: CGPoint(x: underlineX + underlineWidth, y: y))
        context.strokePath()
        return y
    }

    func drawFooter(
        in context: CGContext,
        displayData: TradeStatementDisplayData,
        pageRect: CGRect,
        currentY: CGFloat
    ) {
        var y = currentY + 20
        context.setStrokeColor(PDFStylingImproved.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFStylingImproved.margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFStylingImproved.margin, y: y))
        context.strokePath()
        y += 20

        let disclaimerAttributes = PDFTextAttributesImproved.smallAttributes()
        let disclaimerRect = CGRect(x: PDFStylingImproved.margin, y: y, width: PDFStylingImproved.contentWidth, height: 200)
        displayData.legalDisclaimer.draw(in: disclaimerRect, withAttributes: disclaimerAttributes)
        y += 210

        let additionalInfoAttributes = PDFTextAttributesImproved.smallAttributes()
        for info in PDFCompanyInfo.additionalLegalInfo {
            info.draw(at: CGPoint(x: PDFStylingImproved.margin, y: y), withAttributes: additionalInfoAttributes)
            y += PDFStylingImproved.smallFont.lineHeight + 3
        }
    }

    func drawInfoTable(
        in context: CGContext,
        data: [[String]],
        pageRect: CGRect,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFStylingImproved.contentWidth
        let labelWidth = contentWidth * PDFStylingImproved.infoTableLabelWidthRatio
        let valueWidth = contentWidth * PDFStylingImproved.infoTableValueWidthRatio
        let bodyAttributes = PDFTextAttributesImproved.bodyAttributes()

        for (index, row) in data.enumerated() {
            guard row.count >= 2 else { continue }
            let rowRect = CGRect(x: PDFStylingImproved.margin, y: y, width: contentWidth, height: PDFStylingImproved.tableRowHeight)
            if index % 2 == 0 {
                context.setFillColor(PDFStylingImproved.alternateRowBackgroundColor.cgColor)
                context.fill(rowRect)
            }

            let labelRect = CGRect(
                x: PDFStylingImproved.margin + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: labelWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            )
            row[0].draw(in: labelRect, withAttributes: bodyAttributes)

            var valueAttributes = bodyAttributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            valueAttributes[.paragraphStyle] = paragraphStyle
            let valueRect = CGRect(
                x: PDFStylingImproved.margin + labelWidth + PDFStylingImproved.tableCellPadding,
                y: y + (PDFStylingImproved.tableRowHeight - PDFStylingImproved.bodyFont.lineHeight) / 2,
                width: valueWidth - (PDFStylingImproved.tableCellPadding * 2),
                height: PDFStylingImproved.bodyFont.lineHeight
            )
            row[1].draw(in: valueRect, withAttributes: valueAttributes)
            y += PDFStylingImproved.tableRowHeight
        }
        return y
    }
}
