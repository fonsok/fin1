import SwiftUI

// MARK: - Simple Wallet View (Debug Version)
/// Simplified wallet view for testing - shows what should be displayed
struct WalletViewSimple: View {
    @Environment(\.appServices) private var services

    var body: some View {
        let _ = print("💰 WalletViewSimple: body called")
        return ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(6)) {
                    // Balance Card
                    VStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text("Aktuelles Guthaben")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)

                        Text("€ 10.000,00")
                            .font(ResponsiveDesign.largeTitleFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        // Demo Mode Badge
                        HStack(spacing: ResponsiveDesign.spacing(2)) {
                            Image(systemName: "info.circle.fill")
                                .font(ResponsiveDesign.captionFont())
                            Text("Demo-Modus")
                                .font(ResponsiveDesign.captionFont())
                        }
                        .foregroundColor(AppTheme.accentOrange)
                        .padding(.horizontal, ResponsiveDesign.spacing(3))
                        .padding(.vertical, ResponsiveDesign.spacing(2))
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(6))
                    .background(AppTheme.cardBackground)
                    .cornerRadius(ResponsiveDesign.spacing(3))

                    // Quick Actions
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("Schnellaktionen")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)

                        HStack(spacing: ResponsiveDesign.spacing(4)) {
                            // Deposit Button
                            Button {
                                print("💰 Deposit button tapped")
                            } label: {
                                VStack(spacing: ResponsiveDesign.spacing(2)) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: ResponsiveDesign.iconSize()))
                                        .foregroundColor(.white)
                                    Text("Einzahlen")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(ResponsiveDesign.spacing(4))
                                .background(AppTheme.accentGreen)
                                .cornerRadius(ResponsiveDesign.spacing(3))
                            }

                            // Withdrawal Button
                            Button {
                                print("💰 Withdrawal button tapped")
                            } label: {
                                VStack(spacing: ResponsiveDesign.spacing(2)) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: ResponsiveDesign.iconSize()))
                                        .foregroundColor(.white)
                                    Text("Auszahlen")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(ResponsiveDesign.spacing(4))
                                .background(AppTheme.accentRed)
                                .cornerRadius(ResponsiveDesign.spacing(3))
                            }
                        }
                    }

                    // Recent Transactions
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        HStack {
                            Text("Letzte Transaktionen")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Spacer()

                            Button {
                                print("💰 Show all transactions")
                            } label: {
                                Text("Alle anzeigen")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentLightBlue)
                            }
                        }

                        // Empty state
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "tray")
                                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                                .foregroundColor(AppTheme.secondaryText)
                            Text("Noch keine Transaktionen")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ResponsiveDesign.spacing(8))
                    }
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(8))
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            print("💰 WalletViewSimple: onAppear called")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    print("💰 Refresh tapped")
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}
