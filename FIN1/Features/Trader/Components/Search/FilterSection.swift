import SwiftUI

struct FilterSection: View {
    @Binding var strikePriceGap: String?
    @Binding var remainingTerm: String?
    @Binding var issuer: String?
    @Binding var omega: String?
    @Binding var activeSheet: SecuritiesSearchView.ActiveSheet?

    let warrantDetailsViewModel: WarrantDetailsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: ResponsiveDesign.spacing(16)) {
            // Dynamic filter buttons based on warrant details selection
            ForEach(warrantDetailsViewModel.items) { item in
                if item.isSelected {
                    switch item.name {
                    case "Strike Price Gap in %":
                        if strikePriceGap == nil {
                            FilterChipButton(
                                label: "Strike Price Gap",
                                value: strikePriceGap
                            ) {
                                activeSheet = .strikePriceGap
                            }
                        }
                    case "Restlaufzeit":
                        if remainingTerm == nil {
                            FilterChipButton(
                                label: "Restlaufzeit",
                                value: remainingTerm
                            ) {
                                activeSheet = .remainingTerm
                            }
                        }
                    case "Emittent":
                        if issuer == nil {
                            FilterChipButton(
                                label: "Emittent",
                                value: issuer
                            ) {
                                activeSheet = .issuer
                            }
                        }
/*                    case "Omega":
                        if omega == nil {
                            FilterChipButton(
                                label: "Omega",
                                value: omega
                            ) {
                                activeSheet = .omega
                            }
                        }*/
                    default: EmptyView()
                    }
                }
            }
        }
    }
}

#Preview {
    FilterSection(
        strikePriceGap: .constant(nil),
        remainingTerm: .constant(nil),
        issuer: .constant(nil),
        omega: .constant(nil),
        activeSheet: .constant(nil),
        warrantDetailsViewModel: WarrantDetailsViewModel()
    )
    .padding()
    .background(AppTheme.screenBackground)
}
