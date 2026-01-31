import SwiftUI

// MARK: - Address Change Request View

/// View for submitting address change requests with KYC verification
struct AddressChangeRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: AddressChangeRequestViewModel

    init() {
        _viewModel = StateObject(wrappedValue: AddressChangeRequestViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        complianceHeader
                        currentAddressSection
                        newAddressSection
                        documentSection
                        declarationSection
                        errorSection
                        submitSection
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(20))
                }
            }
            .navigationTitle("Address Change Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.fontColor)
                }
            }
            .alert("Request Submitted", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your address change request has been submitted for compliance review.")
            }
        }
        .onAppear { viewModel.configure(with: appServices) }
    }

    // MARK: - Compliance Header

    private var complianceHeader: some View {
        KYCComplianceHeaderView(
            title: "Address Verification Required",
            description: "Due to regulatory requirements (KYC/AML), address changes require verification. Please provide your new address and a valid proof of address document.",
            icon: "house.circle.fill"
        )
    }

    // MARK: - Current Address Section

    private var currentAddressSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "Current Address", badge: "Verified", badgeColor: AppTheme.accentGreen)

            AddressDisplayCard(
                streetAndNumber: viewModel.currentStreetAndNumber,
                postalCode: viewModel.currentPostalCode,
                city: viewModel.currentCity,
                state: viewModel.currentState,
                country: viewModel.currentCountry
            )
        }
    }

    // MARK: - New Address Section

    private var newAddressSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "New Address")

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                LabeledInputField(
                    label: "Street and Number",
                    placeholder: "Enter street and number",
                    icon: "mappin.circle.fill",
                    text: $viewModel.newStreetAndNumber
                )

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    LabeledInputField(
                        label: "Postal Code",
                        placeholder: "Enter postal code",
                        icon: "number",
                        text: $viewModel.newPostalCode,
                        maxLength: 10
                    )
                    LabeledInputField(
                        label: "City",
                        placeholder: "Enter city",
                        icon: "building.2.fill",
                        text: $viewModel.newCity
                    )
                }

                LabeledInputField(
                    label: "State/Province",
                    placeholder: "Enter state or province",
                    icon: "map.fill",
                    text: $viewModel.newState
                )

                LabeledInputField(
                    label: "Country",
                    placeholder: "Enter country",
                    icon: "globe",
                    text: $viewModel.newCountry
                )
            }
        }
    }

    // MARK: - Document Section

    private var documentSection: some View {
        KYCDocumentUploadSection(
            title: "Proof of Address",
            documentTypes: AddressVerificationDocumentType.allCases,
            selectedType: $viewModel.selectedDocumentType,
            selectedImage: $viewModel.selectedDocument,
            documentTypeName: { $0.displayName },
            documentTypeDescription: { $0.description },
            documentTypeIcon: { $0.icon }
        )
    }

    // MARK: - Declaration Section

    private var declarationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "Declaration")

            KYCDeclarationCheckbox(
                isChecked: $viewModel.userDeclaration,
                text: "I declare that the information provided is true and accurate. I understand that providing false information may result in account suspension and legal action."
            )
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            KYCErrorMessageView(message: error)
        }
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        KYCSubmitButton(
            title: "Submit Address Change Request",
            isEnabled: viewModel.isFormValid,
            isLoading: viewModel.isLoading,
            action: { Task { await viewModel.submitRequest() } }
        )
    }
}

// MARK: - Address Display Card

private struct AddressDisplayCard: View {
    let streetAndNumber: String
    let postalCode: String
    let city: String
    let state: String
    let country: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            Text(streetAndNumber)
            Text("\(postalCode) \(city)")
            if !state.isEmpty { Text(state) }
            Text(country)
        }
        .font(ResponsiveDesign.bodyFont())
        .foregroundColor(AppTheme.fontColor.opacity(0.9))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview

#Preview {
    AddressChangeRequestView()
}
