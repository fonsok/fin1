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
            ForEach(self.warrantDetailsViewModel.items) { item in
                if item.isSelected {
                    switch item.name {
                    case "Strike Price Gap in %":
                        if self.strikePriceGap == nil {
                            FilterChipButton(
                                label: "Strike Price Gap",
                                value: self.strikePriceGap
                            ) {
                                self.activeSheet = .strikePriceGap
                            }
                        }
                    case "Restlaufzeit":
                        if self.remainingTerm == nil {
                            FilterChipButton(
                                label: "Restlaufzeit",
                                value: self.remainingTerm
                            ) {
                                self.activeSheet = .remainingTerm
                            }
                        }
                    case "Emittent":
                        if self.issuer == nil {
                            FilterChipButton(
                                label: "Emittent",
                                value: self.issuer
                            ) {
                                self.activeSheet = .issuer
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
