import SwiftUI

/// Sheet to assign selected tickets to an agent.
struct BulkAssignSheet: View {
    let selectedCount: Int
    let agents: [CSRAgent]
    let onAssign: (String) -> Void

    @State private var selectedAgentId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("\(self.selectedCount) Tickets zuweisen an:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                ScrollView {
                    LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                        ForEach(self.agents.filter { $0.canAcceptTickets }) { agent in
                            Button {
                                self.selectedAgentId = agent.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(agent.name)
                                            .font(ResponsiveDesign.bodyFont())
                                            .foregroundColor(AppTheme.fontColor)

                                        Text("\(agent.currentTicketCount)/\(CSRAgent.maxTickets) Tickets")
                                            .font(ResponsiveDesign.captionFont())
                                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                                    }

                                    Spacer()

                                    Image(systemName: self.selectedAgentId == agent.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(
                                            self.selectedAgentId == agent.id ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.3)
                                        )
                                }
                                .padding()
                                .background(
                                    self.selectedAgentId == agent.id ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground
                                )
                                .cornerRadius(ResponsiveDesign.spacing(10))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Agent auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zuweisen") {
                        if let agentId = selectedAgentId {
                            self.onAssign(agentId)
                        }
                    }
                    .disabled(self.selectedAgentId == nil)
                }
            }
        }
    }
}
