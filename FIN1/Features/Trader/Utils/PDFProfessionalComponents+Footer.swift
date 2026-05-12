import Foundation
import UIKit

extension PDFProfessionalComponents {
    // MARK: - Totals / Footer

    static func drawTotalsSection(
        in context: CGContext,
        pageRect: CGRect,
        items: [(label: String, value: String, isFinal: Bool)],
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + PDFDocumentLayout.sectionSpacing
        let totalsX = pageRect.width - PDFDocumentLayout.rightMargin - PDFDocumentLayout.totalsWidth
        let totalsHeight = CGFloat(items.count) * PDFDocumentLayout.totalsRowHeight + 16
        let totalsRect = CGRect(x: totalsX - 8, y: y - 4, width: PDFDocumentLayout.totalsWidth + 8, height: totalsHeight)
        context.setFillColor(PDFColorScheme.totalsBackground.cgColor)
        context.fill(totalsRect)
        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.stroke(totalsRect)
        y += 4

        for item in items {
            let labelAttributes = item.isFinal ? PDFTypography.bodyBoldAttributes() : PDFTypography.totalsLabelAttributes()
            let valueAttributes = item.isFinal ? PDFTypography.totalsFinalAttributes() : PDFTypography.totalsValueAttributes()
            if item.isFinal {
                let finalRowRect = CGRect(
                    x: totalsX - 4,
                    y: y - 2,
                    width: PDFDocumentLayout.totalsWidth + 4,
                    height: PDFDocumentLayout.totalsRowHeight
                )
                context.setFillColor(PDFColorScheme.totalsFinalBackground.cgColor)
                context.fill(finalRowRect)
            }
            item.label.draw(at: CGPoint(x: totalsX, y: y), withAttributes: labelAttributes)
            let valueRect = CGRect(
                x: totalsX, y: y, width: PDFDocumentLayout.totalsWidth - 4,
                height: item.isFinal ? PDFTypography.headerFont.lineHeight : PDFTypography.bodyFont.lineHeight
            )
            item.value.draw(in: valueRect, withAttributes: valueAttributes)
            y += PDFDocumentLayout.totalsRowHeight
        }
        return y + 8
    }

    static func drawFooter(
        in context: CGContext,
        pageRect: CGRect,
        notes: [String] = [],
        currentY: CGFloat
    ) {
        var y = currentY
        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: y))
        context.strokePath()
        y += 12

        let notesAttributes = PDFTypography.smallAttributes()
        for note in notes where !note.isEmpty {
            let noteRect = CGRect(x: PDFDocumentLayout.leftMargin, y: y, width: PDFDocumentLayout.contentWidth, height: 60)
            note.draw(in: noteRect, withAttributes: notesAttributes)
            y += 65
        }

        let legalY = pageRect.height - PDFDocumentLayout.bottomMargin - PDFDocumentLayout.footerHeight
        var footerY = max(y + 20, legalY)
        context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: footerY))
        context.addLine(to: CGPoint(x: pageRect.width - PDFDocumentLayout.rightMargin, y: footerY))
        context.strokePath()
        footerY += 8

        let footerAttributes = PDFTypography.smallAttributes(alignment: .center)
        for line in PDFCompanyInfo.additionalLegalInfo {
            let lineRect = CGRect(
                x: PDFDocumentLayout.leftMargin,
                y: footerY,
                width: PDFDocumentLayout.contentWidth,
                height: PDFDocumentLayout.footerLineHeight
            )
            line.draw(in: lineRect, withAttributes: footerAttributes)
            footerY += PDFDocumentLayout.footerLineHeight + 2
        }
    }

    static func drawNotesSection(
        in context: CGContext,
        pageRect: CGRect,
        taxNote: String?,
        legalNote: String?,
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY + PDFDocumentLayout.sectionSpacing
        let notesAttributes = PDFTypography.smallAttributes()
        let contentWidth = PDFDocumentLayout.contentWidth

        if let taxNote = taxNote, !taxNote.isEmpty {
            "Steuerhinweis:".draw(at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y), withAttributes: PDFTypography.smallAttributes())
            y += PDFTypography.smallFont.lineHeight + 2
            let taxNoteRect = CGRect(x: PDFDocumentLayout.leftMargin, y: y, width: contentWidth, height: 40)
            taxNote.draw(in: taxNoteRect, withAttributes: notesAttributes)
            y += 45
        }
        if let legalNote = legalNote, !legalNote.isEmpty {
            "Rechtlicher Hinweis:".draw(at: CGPoint(x: PDFDocumentLayout.leftMargin, y: y), withAttributes: PDFTypography.smallAttributes())
            y += PDFTypography.smallFont.lineHeight + 2
            let legalNoteRect = CGRect(x: PDFDocumentLayout.leftMargin, y: y, width: contentWidth, height: 40)
            legalNote.draw(in: legalNoteRect, withAttributes: notesAttributes)
            y += 45
        }
        return y
    }
}
