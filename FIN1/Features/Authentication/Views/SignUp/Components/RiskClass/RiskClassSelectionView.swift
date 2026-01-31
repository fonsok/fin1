import SwiftUI

struct RiskClassSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRiskClass: RiskClass?
    let calculatedRiskClass: RiskClass
    let onRiskClass7Confirmed: (() -> Void)?
    @State private var showRiskClass7Warning = false
    @State private var tempSelectedRiskClass: RiskClass?
    @State private var showRiskClassInfo = false

    init(selectedRiskClass: Binding<RiskClass?>, calculatedRiskClass: RiskClass, onRiskClass7Confirmed: (() -> Void)? = nil) {
        self._selectedRiskClass = selectedRiskClass
        self.calculatedRiskClass = calculatedRiskClass
        self.onRiskClass7Confirmed = onRiskClass7Confirmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        // Header
                        VStack(spacing: ResponsiveDesign.spacing(12)) {
                            Text("Risikoklasse wählen")
                                .font(ResponsiveDesign.titleFont())
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.fontColor)

                            Text("Basierend auf Ihren Angaben wurde folgende Risikoklasse berechnet:")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Calculated Risk Class
                        VStack(spacing: ResponsiveDesign.spacing(16)) {
                            HStack {
                                Image(systemName: "calculator")
                                    .foregroundColor(AppTheme.accentLightBlue)
                                    .font(ResponsiveDesign.titleFont())

                                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                                    Text("Berechnete Risikoklasse")
                                        .font(ResponsiveDesign.headlineFont())
                                        .foregroundColor(AppTheme.fontColor)

                                    Text(calculatedRiskClass.displayName)
                                        .font(ResponsiveDesign.bodyFont())
                                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                }

                                Spacer()

                                // Risk indicator
                                HStack(spacing: ResponsiveDesign.spacing(4)) {
                                    ForEach(1...7, id: \.self) { index in
                                        Circle()
                                            .fill(index <= calculatedRiskClass.rawValue ? calculatedRiskClass.color : Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            .padding()
                            .background(AppTheme.accentLightBlue.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(12))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                    .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())

                        // Manual Selection
                        VStack(spacing: ResponsiveDesign.spacing(16)) {
                            HStack {
                                Text("Manuelle Auswahl")
                                    .font(ResponsiveDesign.headlineFont())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.fontColor)

                                Spacer()

                                Button("Info") {
                                    showRiskClassInfo = true
                                }
                                .foregroundColor(AppTheme.accentLightBlue)
                                .font(ResponsiveDesign.captionFont())
                            }

                            Text("Sie können eine andere Risikoklasse wählen, falls Sie mit der Berechnung nicht einverstanden sind:")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                                .multilineTextAlignment(.leading)

                            // Risk Class Options
                            VStack(spacing: ResponsiveDesign.spacing(8)) {
                                ForEach(RiskClass.allCases, id: \.rawValue) { riskClass in
                                    RiskClassOptionRow(
                                        riskClass: riskClass,
                                        isSelected: tempSelectedRiskClass == riskClass,
                                        onSelect: { selectedClass in
                                            if selectedClass == .riskClass7 {
                                                tempSelectedRiskClass = selectedClass
                                                showRiskClass7Warning = true
                                            } else {
                                                tempSelectedRiskClass = selectedClass
                                            }
                                        }
                                    )
                                }
                            }

                            // Clear Selection Button
                            if tempSelectedRiskClass != nil {
                                Button("Automatische Berechnung verwenden") {
                                    tempSelectedRiskClass = nil
                                }
                                .foregroundColor(AppTheme.accentLightBlue)
                                .font(ResponsiveDesign.bodyFont())
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
                    }
                }
            }
            .navigationTitle("Risikoklasse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Bestätigen") {
                        selectedRiskClass = tempSelectedRiskClass
                        dismiss()

                        // If Risk Class 7 was confirmed, trigger navigation to Summary
                        if tempSelectedRiskClass == .riskClass7 {
                            onRiskClass7Confirmed?()
                        }
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                    .disabled(tempSelectedRiskClass == nil && selectedRiskClass == nil)
                }
            }
        }
        .sheet(isPresented: $showRiskClassInfo) {
            RiskClassInfoView()
        }
        .alert("Hochrisiko-Warnung", isPresented: $showRiskClass7Warning) {
            Button("Abbrechen") {
                tempSelectedRiskClass = nil
            }
            Button("Bestätigen") {
                // Keep the selection
            }
        } message: {
            Text("Risikoklasse 7 ist nur für erfahrene Anleger geeignet. Es besteht das Risiko des Totalverlusts Ihres Kapitals. Sind Sie sicher, dass Sie diese Risikoklasse wählen möchten?")
        }
    }
}

struct RiskClassOptionRow: View {
    let riskClass: RiskClass
    let isSelected: Bool
    let onSelect: (RiskClass) -> Void

    var body: some View {
        Button(action: {
            onSelect(riskClass)
        }) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accentLightBlue : .gray)
                    .font(ResponsiveDesign.headlineFont())

                // Risk class info
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(riskClass.displayName)
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        // Risk indicator
                        HStack(spacing: ResponsiveDesign.spacing(2)) {
                            ForEach(1...7, id: \.self) { index in
                                Circle()
                                    .fill(index <= riskClass.rawValue ? riskClass.color : Color.gray.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }

                    Text(riskClass.description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .stroke(isSelected ? AppTheme.accentLightBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RiskClassSelectionView(
        selectedRiskClass: .constant(nil),
        calculatedRiskClass: .riskClass3,
        onRiskClass7Confirmed: nil
    )
}
