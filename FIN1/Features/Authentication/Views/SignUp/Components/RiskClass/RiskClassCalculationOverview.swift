import SwiftUI

struct RiskClassCalculationOverview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Text("Risk Class Calculation Overview")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                // Step 12: Financial Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Step 12: Financial Information")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    // Income Range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Income Range")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Under 25.000", points: 0)
                            RiskFactorRow(factor: "25.000 - 50.000", points: 1)
                            RiskFactorRow(factor: "50.000 - 100.000", points: 2)
                            RiskFactorRow(factor: "100.000 - 200.000", points: 3)
                            RiskFactorRow(factor: "200.000 - 500.000", points: 4)
                            RiskFactorRow(factor: "More than 500.000", points: 5, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    // Cash and Liquid Assets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cash and Liquid Assets")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Less than 10.000", points: 0)
                            RiskFactorRow(factor: "10.000 - 50.000", points: 1)
                            RiskFactorRow(factor: "50.000 - 100.000", points: 2)
                            RiskFactorRow(factor: "100.000 - 500.000", points: 3)
                            RiskFactorRow(factor: "500.000 - 1.000.000", points: 4)
                            RiskFactorRow(factor: "More than 1.000.000", points: 5, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    // Income Sources
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Income Sources")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Assets", points: 2, isHighlighted: true)
                            RiskFactorRow(factor: "Inheritance", points: 1)
                            RiskFactorRow(factor: "Settlement", points: 1)
                            RiskFactorRow(factor: "Salary/Pension/Savings", points: 0)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Step 13: Investment Experience
                VStack(alignment: .leading, spacing: 16) {
                    Text("Step 13: Investment Experience")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    // Transaction Counts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Counts")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Stocks: None", points: 0)
                            RiskFactorRow(factor: "Stocks: 1-10", points: 1)
                            RiskFactorRow(factor: "Stocks: 10-50", points: 2)
                            RiskFactorRow(factor: "Stocks: 50+", points: 3)

                            Divider()

                            RiskFactorRow(factor: "ETFs: None", points: 0)
                            RiskFactorRow(factor: "ETFs: 1-10", points: 1)
                            RiskFactorRow(factor: "ETFs: 10-20", points: 2)
                            RiskFactorRow(factor: "ETFs: 20+", points: 3)

                            Divider()

                            RiskFactorRow(factor: "Derivatives: None", points: 0)
                            RiskFactorRow(factor: "Derivatives: 1-10", points: 3, isHighlighted: true)
                            RiskFactorRow(factor: "Derivatives: 10-50", points: 6, isHighlighted: true)
                            RiskFactorRow(factor: "Derivatives: 50+", points: 8, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    // Investment Amounts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Investment Amounts (Maximum of all types)")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Stocks/ETFs: 100€ - 10.000€", points: 0)
                            RiskFactorRow(factor: "Stocks/ETFs: 10.000€ - 100.000€", points: 1)
                            RiskFactorRow(factor: "Stocks/ETFs: 100.000€ - 1.000.000€", points: 2)
                            RiskFactorRow(factor: "Stocks/ETFs: More than 1.000.000€", points: 4)

                            Divider()

                            RiskFactorRow(factor: "Derivatives: 0€ - 1.000€", points: 0)
                            RiskFactorRow(factor: "Derivatives: 1.000€ - 10.000€", points: 2, isHighlighted: true)
                            RiskFactorRow(factor: "Derivatives: 10.000€ - 100.000€", points: 4, isHighlighted: true)
                            RiskFactorRow(factor: "Derivatives: More than 100.000€", points: 6, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    // Derivatives Holding Period
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Derivatives Holding Period")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Months to years", points: 1)
                            RiskFactorRow(factor: "Days to weeks", points: 2)
                            RiskFactorRow(factor: "Minutes to hours", points: 4, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    // Other Assets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other Assets")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "Real estate", points: 2, isHighlighted: true)
                            RiskFactorRow(factor: "Gold, silver", points: 1)
                            RiskFactorRow(factor: "None", points: 0)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Step 14: Desired Return
                VStack(alignment: .leading, spacing: 16) {
                    Text("Step 14: Desired Return")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Return Expectations")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        VStack(alignment: .leading, spacing: 4) {
                            RiskFactorRow(factor: "At least 10%", points: 1)
                            RiskFactorRow(factor: "At least 50%", points: 3)
                            RiskFactorRow(factor: "At least 100%", points: 5, isHighlighted: true)
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Risk Class Mapping
                VStack(alignment: .leading, spacing: 16) {
                    Text("Risk Class Mapping")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            RiskClassRow(riskClass: "Risk Class 1", range: "0-3 points", description: "Very Low Risk")
                            RiskClassRow(riskClass: "Risk Class 2", range: "4-7 points", description: "Low Risk")
                            RiskClassRow(riskClass: "Risk Class 3", range: "8-12 points", description: "Medium Risk")
                            RiskClassRow(riskClass: "Risk Class 4", range: "13-18 points", description: "Medium-High Risk")
                            RiskClassRow(riskClass: "Risk Class 5", range: "19-25 points", description: "High Risk")
                            RiskClassRow(riskClass: "Risk Class 6", range: "26-35 points", description: "Very High Risk")
                        }
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Example Calculations
                VStack(alignment: .leading, spacing: 16) {
                    Text("Example Calculations")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    VStack(alignment: .leading, spacing: 12) {
                        ExampleCalculation(
                            title: "Beginner (Conservative)",
                            factors: [
                                "Income: Middle (2 points)",
                                "Assets: Less than 10k (0 points)",
                                "No investment experience (0 points)",
                                "Desired return: 10% (1 point)"
                            ],
                            total: 3,
                            riskClass: "Risk Class 1"
                        )

                        ExampleCalculation(
                            title: "50+ Derivatives Experience",
                            factors: [
                                "Income: Middle (2 points)",
                                "Assets: Less than 10k (0 points)",
                                "Derivatives: 50+ transactions (8 points)",
                                "Derivatives holding: Months to years (1 point)",
                                "Desired return: 10% (1 point)"
                            ],
                            total: 12,
                            riskClass: "Risk Class 3"
                        )

                        ExampleCalculation(
                            title: "High-Risk Profile",
                            factors: [
                                "Income: Very high (5 points)",
                                "Assets: More than 1M (5 points)",
                                "Derivatives: 50+ transactions (8 points)",
                                "Derivatives: More than 100k (6 points)",
                                "Derivatives holding: Minutes to hours (4 points)",
                                "Desired return: 100% (5 points)",
                                "Real estate: Yes (2 points)"
                            ],
                            total: 35,
                            riskClass: "Risk Class 6"
                        )
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.screenBackground)
    }
}

struct RiskFactorRow: View {
    let factor: String
    let points: Int
    let isHighlighted: Bool

    init(factor: String, points: Int, isHighlighted: Bool = false) {
        self.factor = factor
        self.points = points
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        HStack {
            Text(factor)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            Text("\(points) pts")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(isHighlighted ? AppTheme.accentOrange : AppTheme.fontColor)
        }
    }
}

struct RiskClassRow: View {
    let riskClass: String
    let range: String
    let description: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(riskClass)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()

            Text(range)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.accentLightBlue)
        }
    }
}

struct ExampleCalculation: View {
    let title: String
    let factors: [String]
    let total: Int
    let riskClass: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(factors, id: \.self) { factor in
                    Text("• \(factor)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                }
            }

            HStack {
                Text("Total:")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text("\(total) points")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentLightBlue)

                Spacer()

                Text(riskClass)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground.opacity(0.5))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

#Preview {
    RiskClassCalculationOverview()
}
