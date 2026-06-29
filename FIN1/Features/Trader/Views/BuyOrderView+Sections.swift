import SwiftUI

extension BuyOrderView {

    var securitiesDetailsSection: some View {
        SecuritiesDetailsSection(
            direction: self.viewModel.searchResult.category == "Optionsschein" ? self.viewModel.searchResult.direction : nil,
            basiswert: self.viewModel.searchResult.category == "Optionsschein" ? self.viewModel.searchResult.underlyingAsset : nil,
            strike: BuyOrderViewFormatting.formatStrikePrice(
                self.viewModel.searchResult.strike,
                self.viewModel.searchResult.underlyingAsset
            ),
            valuationDate: self.viewModel.searchResult.valuationDate,
            wkn: self.viewModel.searchResult.wkn,
            currentPrice: self.viewModel.formattedAskPrice,
            priceLabel: "Brief-Kurs (Ask)",
            priceValidityProgress: self.viewModel.priceValidityProgress,
            onReloadPrice: {
                self.viewModel.reloadPrice()
            },
            isLimitOrder: self.viewModel.orderMode == .limit,
            limitPrice: self.viewModel.limitPrice,
            currentPriceValue: self.viewModel.currentPriceValue,
            isMonitoringLimitOrder: self.viewModel.isMonitoringLimitOrder,
            orderType: "buy"
        )
    }

    var orderDetailsSection: some View {
        OrderDetailsSection {
            QuantityInputField(
                text: self.$viewModel.quantityText,
                isFocused: self.$quantityFieldFocused,
                placeholder: "Stück",
                accessibilityLabel: "Number of shares",
                accessibilityHint: "Enter the number of shares you want to buy",
                onSubmit: {
                    self.viewModel.normalizeQuantityTextAfterEditing()
                },
                maxValueWarning: self.viewModel.showMaxValueWarning ?
                    QuantityInputField.MaxValueWarning(
                        enteredValue: Int(self.viewModel.quantity),
                        maxValue: 10_000_000
                    ) : nil,
                errorMessage: self.viewModel.quantityConstraintMessage
            )
            .onChange(of: self.quantityFieldFocused) { _, isFocused in
                if !isFocused {
                    self.viewModel.normalizeQuantityTextAfterEditing()
                }
            }

            OrderTypeSelection(
                selectedOrderMode: self.$viewModel.orderMode,
                onOrderModeChanged: { newOrderMode in
                    self.viewModel.orderMode = newOrderMode
                }
            )

            LimitPriceInput(
                limitText: self.$viewModel.limit,
                isVisible: self.viewModel.orderMode == .limit,
                onChange: { newValue in
                    #if DEBUG
                    print("🔍 DEBUG: Limit field changed to: '\(newValue)'")
                    #endif
                },
                validationMessage: self.limitValidationMessage,
                placeholder: "Beispiel: 1,23"
            )
        }
    }

    var costEstimateSection: some View {
        HStack {
            Text("Kosten (geschätzt)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(self.viewModel.estimatedCost.formattedAsLocalizedCurrency())
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentOrange.opacity(0.8))
                .fontWeight(.medium)
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }

    @ViewBuilder
    var insufficientFundsWarningSection: some View {
        if self.viewModel.showInsufficientFundsWarning {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    Text("!")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.red)
                }

                Text(self.viewModel.insufficientFundsMessage)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    @ViewBuilder
    var transactionLimitWarningSection: some View {
        if self.viewModel.showLimitWarning {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.orange)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    Text(self.transactionLimitWarningTitle)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.orange)
                }

                if let intro = transactionLimitIntroText {
                    Text(intro)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)
                }

                if let message = viewModel.limitWarningMessage {
                    Text(message)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(ResponsiveDesign.spacing(10))
        } else if let remainingLimit = viewModel.remainingDailyLimit {
            let dailyLimit = (viewModel.transactionLimitCheckResult?.remainingDaily ?? 0) + self.viewModel.estimatedCost
            let usagePercent = dailyLimit > 0 ? (1.0 - remainingLimit / dailyLimit) : 0

            if usagePercent > 0.5 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                    Text("Verbleibendes Tageslimit: \(remainingLimit.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    var priceValidityWarningSection: some View {
        if !self.isPlacingOrder,
           self.viewModel.priceValidityProgress > 0,
           self.viewModel.priceValidityProgress < BuyOrderPriceStaleness.elevatedWarningThreshold {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text(BuyOrderPriceStaleness.possiblyStaleMessage)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(10))
        } else if !self.isPlacingOrder, self.viewModel.priceValidityProgress <= 0 {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(BuyOrderPriceStaleness.likelyStaleMessage)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.red.opacity(0.08))
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    @ViewBuilder
    var orderPlacementStatusSection: some View {
        if self.isPlacingOrder {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                ProgressView()
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Kauf-Order wird übermittelt…")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.primaryText)
                    Text("Pool-Daten und Server werden abgefragt. Nach einem Neustart kann das kurz dauern.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Kauf-Order wird übermittelt")
        }
    }

    var orderActionButton: some View {
        OrderActionButton(
            title: "(Gebührenpflichtig) Kaufen",
            backgroundColor: AppTheme.buttonColor,
            isEnabled: self.viewModel.canPlaceOrder && !self.viewModel.showLimitWarning,
            isLoading: self.isPlacingOrder,
            action: {
                #if DEBUG
                print("🔘 DEBUG: Buy button tapped in form section")
                #endif
                self.viewModel.prepareForPlacement()
                Task {
                    await self.viewModel.placeOrder()
                }
            }
        )
        .accessibilityIdentifier("PlaceOrderButton")
        .accessibilityLabel("Buy order button")
        .accessibilityHint("Place a buy order for the selected number of shares")
    }

    var limitValidationMessage: String? {
        if self.viewModel.orderMode == .limit {
            if self.viewModel.limit.isEmpty {
                return "⚠️ Bitte geben Sie einen Limitpreis ein"
            } else if let limitPrice = viewModel.limitPrice, limitPrice > 0 {
                return "✓ Limitpreis gesetzt: \(String(format: "%.2f", limitPrice).replacingOccurrences(of: ".", with: ","))"
            } else {
                return "⚠️ Ungültiges Format - nur Zahlen und ein Komma erlaubt (z.B. 1,23)"
            }
        }
        return nil
    }
}

enum BuyOrderViewFormatting {
    static func formatStrikePrice(_ strike: String, _ underlyingAsset: String?) -> String {
        DepotUtils.formatStrikePrice(strike, underlyingAsset)
    }
}
