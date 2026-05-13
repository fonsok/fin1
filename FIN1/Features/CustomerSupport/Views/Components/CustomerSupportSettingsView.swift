import SwiftUI

// MARK: - Customer Support Settings View
/// Settings view for CSR and Admin to configure customer support features

struct CustomerSupportSettingsView: View {
    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var slaMonitoringInterval: TimeInterval = 300.0
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    self.slaMonitoringSection

                    Spacer(minLength: ResponsiveDesign.spacing(20))
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Support-Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task { await self.saveSettings() }
                    }
                    .disabled(self.isSaving)
                    .foregroundColor(AppTheme.accentLightBlue)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.dismiss()
                    }
                }
            }
            .onAppear {
                self.loadCurrentSettings()
            }
            .alert("Einstellungen gespeichert", isPresented: self.$showSaveSuccess) {
                Button("OK") { self.dismiss() }
            } message: {
                Text("Die Support-Einstellungen wurden erfolgreich gespeichert.")
            }
            .alert("Fehler", isPresented: self.$showError) {
                Button("OK") { }
            } message: {
                Text(self.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
        }
    }

    // MARK: - SLA Monitoring Section

    private var slaMonitoringSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(AppTheme.accentOrange)

                Text("SLA-Überwachung")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text(
                "Konfigurieren Sie das Intervall für die automatische Überprüfung von SLA-Verletzungen. Bei Verletzungen werden Tickets automatisch eskaliert."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Prüfintervall")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                HStack {
                    Slider(
                        value: self.$slaMonitoringInterval,
                        in: 60...3_600,
                        step: 60
                    )
                    .tint(AppTheme.accentGreen)

                    Text(self.formatInterval(self.slaMonitoringInterval))
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.inputText)
                        .frame(width: 80, alignment: .trailing)
                }

                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    ForEach([60.0, 300.0, 600.0, 1_800.0, 3_600.0], id: \.self) { interval in
                        Button(self.formatInterval(interval)) {
                            self.slaMonitoringInterval = interval
                        }
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(self.slaMonitoringInterval == interval ? .white : AppTheme.inputText)
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(self.slaMonitoringInterval == interval ? AppTheme.accentGreen : AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(6))
                    }
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private func formatInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes) Min."
        } else {
            let hours = minutes / 60
            return "\(hours) Std."
        }
    }

    private func loadCurrentSettings() {
        self.slaMonitoringInterval = self.services.configurationService.slaMonitoringInterval
    }

    private func saveSettings() async {
        self.isSaving = true
        defer { isSaving = false }

        do {
            try await self.services.configurationService.updateSLAMonitoringInterval(self.slaMonitoringInterval)

            // Restart SLA monitoring with new interval
            self.services.slaMonitoringService.stopMonitoring()
            await self.services.slaMonitoringService.startMonitoring(interval: self.slaMonitoringInterval)

            self.showSaveSuccess = true
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.showError = true
        }
    }
}

#Preview {
    CustomerSupportSettingsView()
        .environment(\.appServices, .live)
}

