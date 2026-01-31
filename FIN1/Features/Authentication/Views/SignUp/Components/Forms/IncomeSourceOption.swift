import SwiftUI

struct IncomeSourceOption: View {
    let title: String
    @Binding var isSelected: Bool
    @Binding var otherText: String

    var body: some View {
        Button(action: { isSelected.toggle() }, label: {
            HStack {
                // Clean square checkbox - double size, no borders
                Rectangle()
                    .fill(isSelected ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                    .frame(width: 32, height: 32) // Double the size (was ~16)
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.fontColor)
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                    )

                if title == "Other (please specify)" && isSelected {
                    TextField("Please specify", text: $otherText)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.inputFieldText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .onChange(of: otherText) { _, newValue in
                            // Only allow A-Z, a-z, -, and spaces, max 20 chars
                            let filtered = newValue.filter { char in
                                char.isLetter || char == "-" || char == " "
                            }
                            if filtered.count <= 20 {
                                otherText = filtered
                            } else {
                                otherText = String(filtered.prefix(20))
                            }
                        }
                } else {
                    Text(title)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
        })
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(8)) {
        IncomeSourceOption(title: "Salary", isSelected: .constant(true), otherText: .constant(""))
        IncomeSourceOption(title: "Savings", isSelected: .constant(false), otherText: .constant(""))
        IncomeSourceOption(title: "Other (please specify)", isSelected: .constant(true), otherText: .constant("Freelance work"))
    }
    .padding()
    .background(AppTheme.screenBackground)
}
