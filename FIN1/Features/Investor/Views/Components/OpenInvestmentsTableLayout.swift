import SwiftUI

@MainActor
enum OpenInvestmentsTableLayout {
    static var columnSpacing: CGFloat { ResponsiveDesign.spacing(16) }
    static var cellHorizontalPadding: CGFloat { ResponsiveDesign.spacing(12) }
    static var cellVerticalPadding: CGFloat { ResponsiveDesign.spacing(6) }
}

struct OpenInvestmentsHeaderCellModifier: ViewModifier {
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
        case "pool": return 60
        case "status": return 80
        case "amount": return 110
        case "profit": return 110
        case "return": return 90
        case "docRef": return 100
        default: return 80
        }
    }
}
