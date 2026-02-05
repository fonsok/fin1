import SwiftUI

/// Shared component for formatting FAQ answer text
/// Handles bullet points, paragraphs, and spacing consistently
struct FAQAnswerFormatter: View {
    let answer: String
    let style: LandingViewModel.DesignStyle

    init(answer: String, style: LandingViewModel.DesignStyle = .original) {
        self.answer = answer
        self.style = style
    }

    var body: some View {
        let lines = answer.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("•") {
                    // Bullet point line
                    HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
                        if style == .typewriter {
                            Text("-")
                                .font(.system(size: 16, weight: .regular, design: .monospaced))
                                .foregroundColor(Color("InputText"))
                                .padding(.top, ResponsiveDesign.spacing(5))
                        } else {
                            Image(systemName: "circle.fill")
                                .font(.system(size: ResponsiveDesign.spacing(10)))
                                .foregroundColor(AppTheme.fontColor.opacity(0.75))
                                .padding(.top, ResponsiveDesign.spacing(5))
                        }

                        Group {
                            if style == .typewriter {
                                Text(line.trimmingCharacters(in: .whitespaces).dropFirst().trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color("InputText"))
                            } else {
                                Text(line.trimmingCharacters(in: .whitespaces).dropFirst().trimmingCharacters(in: .whitespaces))
                                    .expandableContentTextStyle()
                            }
                        }
                    }
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Regular paragraph line
                    Group {
                        if style == .typewriter {
                            Text(line.trimmingCharacters(in: .whitespaces))
                                .font(.system(size: 16, weight: .regular, design: .monospaced))
                                .foregroundColor(Color("InputText"))
                        } else {
                            Text(line.trimmingCharacters(in: .whitespaces))
                                .expandableContentTextStyle()
                        }
                    }
                } else {
                    // Empty line for spacing
                    Spacer()
                        .frame(height: ResponsiveDesign.spacing(4))
                }
            }
        }
    }
}


#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        FAQAnswerFormatter(
            answer: "This is a sample FAQ answer.\n• First bullet point\n• Second bullet point\n\nAnother paragraph with more information.",
            style: .original
        )

        FAQAnswerFormatter(
            answer: "This is a sample FAQ answer.\n• First bullet point\n• Second bullet point\n\nAnother paragraph with more information.",
            style: .typewriter
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}

