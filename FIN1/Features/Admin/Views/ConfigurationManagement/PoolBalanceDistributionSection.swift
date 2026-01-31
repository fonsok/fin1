import SwiftUI

// MARK: - Pool Balance Distribution Section

/// Component for managing pool balance distribution strategy and threshold
struct PoolBalanceDistributionSection: View {
    @Environment(\.appServices) private var appServices
    @ObservedObject var viewModel: ConfigurationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Pool Balance Distribution")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(.primary)

            // Strategy Selection
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Distribution Strategy")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)

                // Strategy selection buttons - explicit buttons for clarity
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    // Option 1: Immediate Distribution
                    Button(action: {
                        viewModel.poolBalanceDistributionStrategy = PoolBalanceDistributionStrategy.immediateDistribution
                        Task {
                            await viewModel.updatePoolBalanceDistributionStrategy(appServices.configurationService)
                        }
                    }) {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("Option 1")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.bold)

                            Text("Immediate")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)

                            Text("Distribute immediately")
                                .font(ResponsiveDesign.captionFont())
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .foregroundColor(viewModel.poolBalanceDistributionStrategy == .immediateDistribution ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
                        .padding(ResponsiveDesign.spacing(12))
                        .background(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .fill(
                                    viewModel.poolBalanceDistributionStrategy == .immediateDistribution
                                        ? AppTheme.accentLightBlue
                                        : AppTheme.sectionBackground
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .stroke(
                                    viewModel.poolBalanceDistributionStrategy == .immediateDistribution
                                        ? AppTheme.accentLightBlue
                                        : Color.gray.opacity(0.5),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    // Option 2: Accumulate Until Threshold
                    Button(action: {
                        viewModel.poolBalanceDistributionStrategy = PoolBalanceDistributionStrategy.accumulateUntilThreshold
                        Task {
                            await viewModel.updatePoolBalanceDistributionStrategy(appServices.configurationService)
                        }
                    }) {
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Text("Option 2")
                                .font(ResponsiveDesign.headlineFont())
                                .fontWeight(.bold)

                            Text("Accumulate")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.semibold)

                            Text("Keep until threshold")
                                .font(ResponsiveDesign.captionFont())
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .foregroundColor(viewModel.poolBalanceDistributionStrategy == .accumulateUntilThreshold ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
                        .padding(ResponsiveDesign.spacing(12))
                        .background(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .fill(
                                    viewModel.poolBalanceDistributionStrategy == .accumulateUntilThreshold
                                        ? AppTheme.accentLightBlue
                                        : AppTheme.sectionBackground
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                                .stroke(
                                    viewModel.poolBalanceDistributionStrategy == .accumulateUntilThreshold
                                        ? AppTheme.accentLightBlue
                                        : Color.gray.opacity(0.5),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }

                // Description text below buttons
                Text(viewModel.poolBalanceDistributionStrategy.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                    .padding(.top, ResponsiveDesign.spacing(4))
            }

            // Threshold Input
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Text("Distribution Threshold")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)

                    Spacer()

                    Text(viewModel.formattedCurrency(appServices.configurationService.poolBalanceDistributionThreshold))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.secondary)
                }

                Text("Remaining balance below this amount will trigger distribution")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Enter threshold", value: $viewModel.poolBalanceDistributionThresholdInput, format: .currency(code: "EUR"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)

                    Button("Update") {
                        Task {
                            await viewModel.updatePoolBalanceDistributionThreshold(appServices.configurationService)
                        }
                    }
                    .disabled(!viewModel.isValidPoolBalanceDistributionThreshold)
                    .buttonStyle(.borderedProminent)
                }

                if let error = viewModel.poolBalanceDistributionThresholdError {
                    Text(error)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.red)
                }
            }
        }
    }
}

