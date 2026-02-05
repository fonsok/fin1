import SwiftUI

// MARK: - Email Template Editor View

/// View for viewing and editing email templates
struct EmailTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var templates: [EmailTemplate] = EmailTemplate.defaults
    @State private var selectedTemplate: EmailTemplate?
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    headerInfo
                    templateList
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("E-Mail-Vorlagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                EmailTemplateDetailView(template: template) { updatedTemplate in
                    if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) {
                        templates[index] = updatedTemplate
                    }
                }
            }
        }
    }

    // MARK: - Header Info

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "envelope.badge.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("E-Mail-Vorlagen")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Passen Sie die automatischen E-Mail-Benachrichtigungen an")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }

            Divider()

            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.captionFont())

                Text("Verwenden Sie Platzhalter wie {{customerName}} für dynamische Inhalte")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Template List

    private var templateList: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            ForEach(templates) { template in
                EmailTemplateRow(template: template) {
                    selectedTemplate = template
                }
            }
        }
    }
}

// MARK: - Email Template Row

private struct EmailTemplateRow: View {
    let template: EmailTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Icon
                Image(systemName: template.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(template.type.rawValue)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(template.subject)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Status
                Circle()
                    .fill(template.isActive ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
                    .frame(width: 8, height: 8)

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Email Template Detail View

private struct EmailTemplateDetailView: View {
    let template: EmailTemplate
    let onSave: (EmailTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var subject: String
    @State private var bodyContent: String
    @State private var isActive: Bool
    @State private var showPreview = false

    init(template: EmailTemplate, onSave: @escaping (EmailTemplate) -> Void) {
        self.template = template
        self.onSave = onSave
        _subject = State(initialValue: template.subject)
        _bodyContent = State(initialValue: template.bodyTemplate)
        _isActive = State(initialValue: template.isActive)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    // Status Toggle
                    HStack {
                        Text("Vorlage aktiv")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Toggle("", isOn: $isActive)
                            .labelsHidden()
                            .tint(AppTheme.accentGreen)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(10))

                    // Subject
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Betreff")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        TextField("E-Mail-Betreff", text: $subject)
                            .font(ResponsiveDesign.bodyFont())
                            .padding()
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(10))
                    }

                    // Body
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        HStack {
                            Text("Inhalt")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))

                            Spacer()

                            Button {
                                showPreview = true
                            } label: {
                                Label("Vorschau", systemImage: "eye.fill")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentLightBlue)
                            }
                        }

                        TextEditor(text: $bodyContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 300)
                            .padding()
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(10))
                            .scrollContentBackground(.hidden)
                    }

                    // Placeholders
                    placeholdersSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(template.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        let updated = EmailTemplate(
                            id: template.id,
                            type: template.type,
                            subject: subject,
                            bodyTemplate: bodyContent,
                            isActive: isActive,
                            lastModified: Date()
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                EmailPreviewView(
                    template: EmailTemplate(
                        id: template.id,
                        type: template.type,
                        subject: subject,
                        bodyTemplate: bodyContent,
                        isActive: isActive
                    )
                )
            }
        }
    }

    private var placeholdersSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Verfügbare Platzhalter")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            FlowLayoutSimple(spacing: 6) {
                ForEach(template.availablePlaceholders, id: \.self) { placeholder in
                    Button {
                        bodyContent += "{{\(placeholder)}}"
                    } label: {
                        Text("{{\(placeholder)}}")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.accentLightBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentLightBlue.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(6))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Email Preview View

private struct EmailPreviewView: View {
    let template: EmailTemplate
    @Environment(\.dismiss) private var dismiss

    private var sampleValues: [String: String] {
        let surveyBaseURL = "https://\(CompanyContactInfo.website)"
        return [
            "customerName": "Max Mustermann",
            "ticketNumber": "TKT-12345",
            "ticketSubject": "Frage zu meiner Investition",
            "ticketDescription": "Ich habe eine Frage bezüglich meiner letzten Investition...",
            "ticketPriority": "Mittel",
            "companyName": LegalIdentity.companyLegalName,
            "supportEmail": CompanyContactInfo.email,
            "agentName": "Stefan Müller",
            "responseMessage": "Vielen Dank für Ihre Anfrage. Ich habe Ihr Anliegen geprüft...",
            "oldStatus": "Offen",
            "newStatus": "In Bearbeitung",
            "resolutionSummary": "Das Problem wurde behoben, indem...",
            "closureReason": "Problem gelöst",
            "surveyLink": "\(surveyBaseURL)/survey/12345",
            "timeRemaining": "2 Stunden",
            "deadline": "15.01.2026 14:00"
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    // Subject
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Betreff")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Text(template.render(with: sampleValues).subject)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(10))

                    // Body
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inhalt")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Text(template.render(with: sampleValues).body)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(10))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Vorschau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayoutSimple: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResultSimple(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResultSimple(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    struct FlowResultSimple {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    EmailTemplateEditorView()
}

