import SwiftUI

/// Withdrawal sheet for the wallet (amount input, quick amounts, submit).
struct WalletWithdrawalSheet: View {
    @ObservedObject var viewModel: WalletViewModel
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(6)) {
                        VStack(spacing: ResponsiveDesign.spacing(3)) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.accentRed)

                            Text("Auszahlung")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Geben Sie den Betrag ein, den Sie auszahlen möchten")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, ResponsiveDesign.spacing(6))

                        VStack(spacing: ResponsiveDesign.spacing(2)) {
                            Text("Verfügbares Guthaben")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)

                            Text(viewModel.formattedBalance)
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ResponsiveDesign.spacing(4))
                        .background(AppTheme.cardBackground)
                        .cornerRadius(ResponsiveDesign.spacing(3))
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(3)) {
                            Text("Schnellbeträge")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: ResponsiveDesign.spacing(3)) {
                                ForEach([50.0, 100.0, 500.0, 1000.0], id: \.self) { amount in
                                    Button {
                                        let maxAmount = min(amount, viewModel.currentBalance)
                                        viewModel.withdrawalAmount = String(format: "%.2f", maxAmount)
                                    } label: {
                                        Text(amount.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                                            .font(ResponsiveDesign.captionFont())
                                            .fontWeight(.medium)
                                            .foregroundColor(viewModel.withdrawalAmount == String(format: "%.2f", amount) ? .white : AppTheme.fontColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, ResponsiveDesign.spacing(2))
                                            .background(
                                                viewModel.withdrawalAmount == String(format: "%.2f", amount)
                                                ? AppTheme.accentLightBlue : AppTheme.cardBackground
                                            )
                                            .cornerRadius(ResponsiveDesign.spacing(2))
                                    }
                                    .disabled(amount > viewModel.currentBalance)
                                    .opacity(amount > viewModel.currentBalance ? 0.5 : 1.0)
                                }
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("Betrag")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)

                            HStack {
                                Text("€")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.secondaryText)

                                TextField("0,00", text: $viewModel.withdrawalAmount)
                                    .keyboardType(.decimalPad)
                                    .font(ResponsiveDesign.titleFont())
                                    .foregroundColor(AppTheme.fontColor)
                            }
                            .padding(ResponsiveDesign.spacing(4))
                            .background(AppTheme.cardBackground)
                            .cornerRadius(ResponsiveDesign.spacing(3))

                            HStack {
                                Text("Min: \(CalculationConstants.PaymentLimits.minimumWithdrawal.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)

                                Spacer()

                                Text("Max: \(CalculationConstants.PaymentLimits.maximumWithdrawal.formatted(.currency(code: "EUR")))")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.accentRed)
                                Text(error)
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentRed)
                            }
                            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }

                        Button {
                            Task {
                                await viewModel.withdraw()
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Auszahlen")
                                        .font(ResponsiveDesign.bodyFont())
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(4))
                            .background(
                                (viewModel.isLoading || viewModel.withdrawalAmount.isEmpty)
                                ? AppTheme.secondaryText : AppTheme.accentRed
                            )
                            .cornerRadius(ResponsiveDesign.spacing(3))
                        }
                        .disabled(viewModel.isLoading || viewModel.withdrawalAmount.isEmpty)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                        VStack(spacing: ResponsiveDesign.spacing(2)) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(ResponsiveDesign.captionFont())
                                Text("Demo-Modus")
                                    .font(ResponsiveDesign.captionFont())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(AppTheme.accentOrange)

                            Text("Diese Auszahlung wird simuliert. Keine echten Zahlungen werden verarbeitet.")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(3))
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                        Spacer(minLength: ResponsiveDesign.spacing(8))
                    }
                }
            }
            .navigationTitle("Auszahlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
