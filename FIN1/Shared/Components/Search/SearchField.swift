import SwiftUI

struct SearchField: View {
    let label: String
    @Binding var value: String
    var subtitle: String?
    var onTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.value.isEmpty ? self.label : self.value)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.inputFieldText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.inputFieldText)
                }
            }

            Spacer()

            if self.onTap != nil {
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(AppTheme.inputFieldText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .onTapGesture {
            self.onTap?()
        }
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        SearchField(
            label: "Typ",
            value: .constant("Optionsschein"),
            onTap: {}
        )

        SearchField(
            label: "Basiswert",
            value: .constant("DAX"),
            subtitle: "Index - 846900",
            onTap: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
