import Foundation
import UIKit

extension PDFProfessionalComponents {
    // MARK: - Professional Table Drawing

    static func drawTable(
        in context: CGContext,
        pageRect: CGRect,
        columnTitles: [String],
        columnWidths: [CGFloat],
        columnAlignments: [NSTextAlignment],
        rows: [[String]],
        currentY: CGFloat
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFDocumentLayout.contentWidth
        let headerRect = CGRect(
            x: PDFDocumentLayout.leftMargin,
            y: y,
            width: contentWidth,
            height: PDFDocumentLayout.tableHeaderHeight
        )
        context.setFillColor(PDFColorScheme.tableHeaderBackground.cgColor)
        context.fill(headerRect)

        var x = PDFDocumentLayout.leftMargin
        for (index, title) in columnTitles.enumerated() {
            let alignment = columnAlignments[safe: index] ?? .left
            let cellRect = CGRect(
                x: x + PDFDocumentLayout.tableCellPadding,
                y: y + (PDFDocumentLayout.tableHeaderHeight - PDFTypography.tableHeaderFont.lineHeight) / 2,
                width: columnWidths[index] - (PDFDocumentLayout.tableCellPadding * 2),
                height: PDFTypography.tableHeaderFont.lineHeight
            )
            title.draw(in: cellRect, withAttributes: PDFTypography.tableHeaderAttributes(alignment: alignment))
            x += columnWidths[index]
        }
        y += PDFDocumentLayout.tableHeaderHeight

        for (rowIndex, row) in rows.enumerated() {
            let descriptionText = row.first ?? ""
            let lineCount = max(1, descriptionText.components(separatedBy: "\n").count)
            let calculatedRowHeight = max(
                PDFDocumentLayout.tableRowHeight,
                CGFloat(lineCount) * PDFTypography.tableCellFont.lineHeight + (PDFDocumentLayout.tableCellPadding * 2)
            )
            let rowRect = CGRect(x: PDFDocumentLayout.leftMargin, y: y, width: contentWidth, height: calculatedRowHeight)
            if rowIndex % 2 == 0 {
                context.setFillColor(PDFColorScheme.tableRowAlternate.cgColor)
                context.fill(rowRect)
            }
            context.setStrokeColor(PDFColorScheme.borderLight.cgColor)
            context.setLineWidth(PDFDocumentLayout.tableBorderWidth)
            context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y + calculatedRowHeight))
            context.addLine(to: CGPoint(x: PDFDocumentLayout.leftMargin + contentWidth, y: y + calculatedRowHeight))
            context.strokePath()

            x = PDFDocumentLayout.leftMargin
            for (colIndex, cellData) in row.enumerated() {
                guard colIndex < columnWidths.count else { break }
                let alignment = columnAlignments[safe: colIndex] ?? .left
                let cellHeight = (colIndex == 0 && lineCount > 1)
                    ? calculatedRowHeight - (PDFDocumentLayout.tableCellPadding * 2)
                    : PDFTypography.tableCellFont.lineHeight
                let cellY = (colIndex == 0 && lineCount > 1)
                    ? y + PDFDocumentLayout.tableCellPadding
                    : y + (calculatedRowHeight - PDFTypography.tableCellFont.lineHeight) / 2
                let cellRect = CGRect(
                    x: x + PDFDocumentLayout.tableCellPadding,
                    y: cellY,
                    width: columnWidths[colIndex] - (PDFDocumentLayout.tableCellPadding * 2),
                    height: cellHeight
                )
                let attributes = PDFTypography.tableCellAttributes(alignment: alignment)
                if colIndex == 0 && lineCount > 1 {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = alignment
                    paragraphStyle.lineBreakMode = .byWordWrapping
                    var multiLineAttributes = attributes
                    multiLineAttributes[.paragraphStyle] = paragraphStyle
                    cellData.draw(in: cellRect, withAttributes: multiLineAttributes)
                } else {
                    cellData.draw(in: cellRect, withAttributes: attributes)
                }
                x += columnWidths[colIndex]
            }
            y += calculatedRowHeight
        }

        context.setStrokeColor(PDFColorScheme.borderMedium.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: PDFDocumentLayout.leftMargin, y: y))
        context.addLine(to: CGPoint(x: PDFDocumentLayout.leftMargin + contentWidth, y: y))
        context.strokePath()
        return y + 4
    }

    static func drawInfoTable(
        in context: CGContext,
        pageRect: CGRect,
        data: [(label: String, value: String)],
        currentY: CGFloat,
        labelWidthRatio: CGFloat = 0.5
    ) -> CGFloat {
        var y = currentY
        let contentWidth = PDFDocumentLayout.contentWidth
        let labelWidth = contentWidth * labelWidthRatio
        let valueWidth = contentWidth * (1.0 - labelWidthRatio)
        let labelAttributes = PDFTypography.bodyAttributes()
        let valueAttributes = PDFTypography.bodyBoldAttributes(alignment: .right)

        for (index, row) in data.enumerated() {
            let rowHeight = PDFDocumentLayout.tableRowHeight
            let rowRect = CGRect(x: PDFDocumentLayout.leftMargin, y: y, width: contentWidth, height: rowHeight)
            if index % 2 == 0 {
                context.setFillColor(PDFColorScheme.tableRowAlternate.cgColor)
                context.fill(rowRect)
            }
            let labelRect = CGRect(
                x: PDFDocumentLayout.leftMargin + PDFDocumentLayout.tableCellPadding,
                y: y + (rowHeight - PDFTypography.bodyFont.lineHeight) / 2,
                width: labelWidth - PDFDocumentLayout.tableCellPadding,
                height: PDFTypography.bodyFont.lineHeight
            )
            row.label.draw(in: labelRect, withAttributes: labelAttributes)
            let valueRect = CGRect(
                x: PDFDocumentLayout.leftMargin + labelWidth + PDFDocumentLayout.tableCellPadding,
                y: y + (rowHeight - PDFTypography.bodyFont.lineHeight) / 2,
                width: valueWidth - (PDFDocumentLayout.tableCellPadding * 2),
                height: PDFTypography.bodyFont.lineHeight
            )
            row.value.draw(in: valueRect, withAttributes: valueAttributes)
            y += rowHeight
        }
        return y + 8
    }
}
