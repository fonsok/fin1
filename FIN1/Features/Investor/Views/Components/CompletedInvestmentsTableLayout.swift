import SwiftUI

@MainActor
enum CompletedInvestmentsTableLayout {
    static var columnSpacing: CGFloat { ResponsiveDesign.spacing(8) }
}

struct CompletedInvestmentsHeaderCellModifier: ViewModifier {
    let columnKey: String
    let columnWidths: [String: CGFloat]
    let forMeasurement: Bool
    let alignment: Alignment

    func body(content: Content) -> some View {
        if self.forMeasurement {
            content.measureWidth(column: self.columnKey)
        } else {
            content
                .foregroundColor(AppTheme.fontColor)
                .frame(width: self.columnWidths[self.columnKey] ?? self.defaultWidth, alignment: self.alignment)
        }
    }

    private var defaultWidth: CGFloat {
        switch self.columnKey {
        case "investmentNr": return 80
        case "traderUsername": return 60
        case "tradeNr": return 50
        case "amount": return 80
        case "profit": return 80
        case "return": return 60
        case "docRef": return 100
        case "details": return 40
        default: return 60
        }
    }
}
