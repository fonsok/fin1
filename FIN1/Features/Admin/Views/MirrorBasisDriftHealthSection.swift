import SwiftUI

// MARK: - Mirror-Basis Drift Health (Admin Dashboard Section)
//
// Compact SwiftUI section that the AdminDashboardView embeds. It surfaces the
// latest run of the weekly mirror-basis drift cron (see
// `scripts/run-mirror-basis-drift-check.sh` and
// `backend/parse-server/cloud/functions/admin/opsHealth.js`).
//
// Rendering rules (kept deliberately terse so it fits above-the-fold):
//   * Status pill: healthy (green) / degraded (orange) / down (red) / unknown (grey).
//   * Subheadline: "last run Xd ago — checked N, drifted M".
//   * If drifted > 0: show the first up-to-3 drifted investment IDs with delta.
//
// The section is passive — it auto-loads once on appear and offers a refresh
// button. No polling because the cron itself runs weekly and we don't want to
// burn cycles repainting the same numbers.

struct MirrorBasisDriftHealthSection: View {
    @StateObject private var viewModel: MirrorBasisDriftHealthViewModel
    @State private var didInitialLoad = false

    init(apiClient: ParseAPIClientProtocol?) {
        let service: OpsHealthAPIServiceProtocol?
        if let apiClient {
            service = OpsHealthAPIService(apiClient: apiClient)
        } else {
            service = nil
        }
        _viewModel = StateObject(wrappedValue: MirrorBasisDriftHealthViewModel(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            headerRow
            contentBody
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .task {
            if !didInitialLoad {
                didInitialLoad = true
                await viewModel.load()
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: ResponsiveDesign.spacing(10)) {
            Text("System Health — Mirror-Basis Drift")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            statusPill

            Button {
                Task { await viewModel.load() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Reload drift status")
        }
    }

    private var statusPill: some View {
        Text(viewModel.overall.uppercased())
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.bold)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(3))
            .background(viewModel.badgeColor.opacity(0.15))
            .foregroundColor(viewModel.badgeColor)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(viewModel.badgeColor.opacity(0.4), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var contentBody: some View {
        switch viewModel.state {
        case .idle where viewModel.status == nil, .loading where viewModel.status == nil:
            loadingPlaceholder
        case .failed(let message) where viewModel.status == nil:
            failurePlaceholder(message)
        default:
            loadedBody
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: ResponsiveDesign.spacing(6)) {
            ProgressView().scaleEffect(0.7)
            Text("Lade Drift-Status …")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
    }

    private func failurePlaceholder(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Konnte Drift-Status nicht laden")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentRed)
            Text(message)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var loadedBody: some View {
        if let status = viewModel.status {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                if !status.hasSnapshot {
                    Text(status.reason ?? "Noch kein Snapshot.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                } else {
                    summaryLine(status: status)
                    if let reason = status.reason {
                        Text(reason)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(viewModel.badgeColor)
                    }
                    if let samples = status.driftSamples, !samples.isEmpty {
                        driftSamplesBody(samples)
                    }
                }
            }
        }
    }

    private func summaryLine(status: MirrorBasisDriftStatus) -> some View {
        let checked = status.checkedDocuments ?? 0
        let drifted = status.driftedDocuments ?? 0
        return VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            Text("Letzter Lauf: \(viewModel.runAtDisplay)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            Text("Geprüft: \(checked) · Abweichung: \(drifted)")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private func driftSamplesBody(_ samples: [MirrorBasisDriftStatus.DriftSample]) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(3)) {
            Text("Erste auffällige Einträge:")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            ForEach(Array(samples.prefix(3).enumerated()), id: \.offset) { _, sample in
                HStack(spacing: ResponsiveDesign.spacing(6)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                        .font(ResponsiveDesign.captionFont())
                    Text(driftSampleLabel(sample))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(2)
                }
            }
        }
    }

    private func driftSampleLabel(_ sample: MirrorBasisDriftStatus.DriftSample) -> String {
        let id = sample.investmentId ?? sample.docId ?? "?"
        let stored = sample.storedReturnPercentage.map { String(format: "%.2f%%", $0) } ?? "—"
        let derived = sample.derivedReturnPercentage.map { String(format: "%.2f%%", $0) } ?? "—"
        let delta = sample.deltaPp.map { String(format: "Δ %.2fpp", $0) } ?? ""
        return "\(id): gespeichert \(stored) vs. abgeleitet \(derived) \(delta)"
    }
}

#Preview {
    MirrorBasisDriftHealthSection(apiClient: nil)
        .padding()
        .background(AppTheme.screenBackground)
}
