import SwiftUI

struct SearchSection: View {
    @Binding var searchText: String
    let onSearchChange: (String) -> Void
    let onClearSearch: () -> Void
    @Environment(\.themeManager) private var themeManager

    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Search Traders")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            HStack {
                // Tappable search icon
                Button(action: {
                    // Trigger immediate search when magnifying glass is tapped
                    self.debounceTask?.cancel()
                    self.onSearchChange(self.searchText)
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accentLightBlue)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                }
                .buttonStyle(PlainButtonStyle())

                TextField("Enter trader username", text: self.$searchText)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.inputFieldText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        // Trigger immediate search when user presses return/done on keyboard
                        self.debounceTask?.cancel()
                        self.onSearchChange(self.searchText)
                    }
                    .onChange(of: self.searchText) { _, newValue in
                        // Debounce search with longer delay to avoid multiple updates per frame
                        // Cancel previous task to prevent accumulation
                        self.debounceTask?.cancel()

                        // Create new debounce task only if we have input
                        guard !newValue.isEmpty else {
                            self.onSearchChange("")
                            return
                        }

                        self.debounceTask = Task {
                            // Use longer delay to prevent multiple updates per frame
                            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms delay

                            // Only proceed if task wasn't cancelled and we're still the current task
                            guard !Task.isCancelled else { return }

                            // Ensure we're still working with the same search text
                            await MainActor.run {
                                self.onSearchChange(newValue)
                            }
                        }
                    }

                if !self.searchText.isEmpty {
                    Button(action: self.onClearSearch, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.inputFieldPlaceholder)
                            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    })
                }
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(AppTheme.inputFieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(self.searchText.count >= 10 ? AppTheme.accentRed.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(12))
            .opacity(0.7)

            // Character counter
            /*  HStack {
                 Text("Max 10 chars: A-Z, a-z, 0-9")
                     .font(ResponsiveDesign.captionFont())
                     .foregroundColor(AppTheme.fontColor.opacity(0.6))

                 Spacer()

                 Text("\(searchText.count)/10")
                     .font(ResponsiveDesign.captionFont())
                     .foregroundColor(searchText.count >= 10 ? AppTheme.accentRed : AppTheme.fontColor.opacity(0.6))
             }   */

            // Validation message for invalid characters
            if !self.searchText.isEmpty && !self.searchText.allSatisfy({ $0.isLetter || $0.isNumber }) {
                Text("Username can only contain letters and numbers")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
            }
        }
        .onDisappear {
            // Cancel any pending debounce task when view disappears
            self.debounceTask?.cancel()
        }
    }
}

#Preview {
    SearchSection(
        searchText: .constant(""),
        onSearchChange: { _ in },
        onClearSearch: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
