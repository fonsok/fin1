import SwiftUI

struct InteractiveElement: View {
    let isSelected: Bool
    let type: InteractiveElementType
    let color: Color
    
    init(isSelected: Bool, type: InteractiveElementType, color: Color = AppTheme.accentGreen) {
        self.isSelected = isSelected
        self.type = type
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Background shape
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
            
            // Icon overlay
            if isSelected {
                selectedIcon
            } else {
                unselectedIcon
            }
        }
    }
    
    private var selectedIcon: some View {
        Group {
            switch type {
            case .checkbox:
                Image(systemName: "checkmark")
                    .foregroundColor(AppTheme.fontColor)
                    .font(ResponsiveDesign.headlineFont())
            case .radioButton, .confirmationCircle:
                Image(systemName: "checkmark")
                    .foregroundColor(AppTheme.fontColor)
                    .font(ResponsiveDesign.headlineFont())
            }
        }
    }
    
    private var unselectedIcon: some View {
        Group {
            switch type {
            case .checkbox:
                // Empty view - no icon for unselected checkbox
                EmptyView()
            case .radioButton, .confirmationCircle:
                // Empty view - no icon for unselected radio button
                EmptyView()
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return color // Use the accent color for selected state
        } else {
            return AppTheme.inputFieldBackground // Use input field background for unselected
        }
    }
    
    private var cornerRadius: CGFloat {
        switch type {
        case .checkbox:
            return 4
        case .radioButton, .confirmationCircle:
            return 16
        }
    }
}

enum InteractiveElementType {
    case checkbox
    case radioButton
    case confirmationCircle
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        HStack {
            InteractiveElement(isSelected: true, type: .checkbox)
            InteractiveElement(isSelected: false, type: .checkbox)
            Text("Checkboxes")
        }
        
        HStack {
            InteractiveElement(isSelected: true, type: .radioButton)
            InteractiveElement(isSelected: false, type: .radioButton)
            Text("Radio Buttons")
        }
        
        HStack {
            InteractiveElement(isSelected: true, type: .confirmationCircle)
            InteractiveElement(isSelected: false, type: .confirmationCircle)
            Text("Confirmation Circles")
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}
