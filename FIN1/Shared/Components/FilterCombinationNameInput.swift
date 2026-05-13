import SwiftUI

// MARK: - Filter Combination Name Input Component
/// Reusable component for entering filter combination names with validation
struct FilterCombinationNameInput: View {
    @ObservedObject var viewModel: CreateFilterCombinationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Filter Combination Name")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            TextField("Enter a name (max 20 chars)", text: self.$viewModel.combinationName)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.inputFieldText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(8))
                .background(AppTheme.inputFieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(self.viewModel.isNameTooLong ? AppTheme.accentRed.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .cornerRadius(ResponsiveDesign.spacing(12))

            // Character counter and hint
            HStack {
                Text("Max 20 chars: A-Z, a-z, 0-9")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                Spacer()

                Text("\(self.viewModel.characterCount)/20")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.viewModel.isNameTooLong ? AppTheme.accentRed : AppTheme.fontColor.opacity(0.6))
            }

            // Validation messages
            if !self.viewModel.combinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if self.viewModel.isNameTooLong {
                    Text("Name is too long (max 20 characters)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                } else if self.viewModel.hasInvalidCharacters {
                    Text("Name can only contain letters, numbers, and spaces")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                }
            }
        }
    }
}

#Preview {
    FilterCombinationNameInput(viewModel: CreateFilterCombinationViewModel())
        .padding()
        .background(AppTheme.screenBackground)
}
