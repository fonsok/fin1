import SwiftUI

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: EditProfileViewModel

    init() {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        personalInformationSection
                        contactInformationSection
                        addressSection
                        employmentSection
                        errorSection
                        saveButton
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.fontColor)
                }
            }
            .alert("Profile Updated", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been successfully updated.")
            }
            .sheet(isPresented: $viewModel.showAddressChangeRequest) {
                AddressChangeRequestView()
            }
            .sheet(isPresented: $viewModel.showNameChangeRequest) {
                NameChangeRequestView()
            }
        }
        .onAppear { viewModel.configure(with: appServices) }
    }

    // MARK: - Personal Information Section

    private var personalInformationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Personal Information",
                showKYCBadge: viewModel.nameRequiresReKYC,
                showLock: !viewModel.canEditName && !viewModel.nameRequiresReKYC
            )

            if viewModel.hasPendingNameChangeRequest, let request = viewModel.pendingNameChangeRequest {
                EditProfilePendingNameChange(request: request)
            }

            if viewModel.nameRequiresReKYC && !viewModel.hasPendingNameChangeRequest {
                EditProfileKYCMessage(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "GwG Compliance Required",
                    message: "Your identity has been verified. Name changes require re-verification per GwG."
                )
            } else if !viewModel.canEditName && !viewModel.nameRequiresReKYC {
                EditProfileLockMessage(message: viewModel.nameLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileSalutationPicker(
                    title: "Salutation",
                    selection: $viewModel.salutation,
                    isDisabled: viewModel.nameRequiresReKYC || !viewModel.canEditName
                )
                EditProfileInputField(label: "Academic Title", placeholder: "e.g., Dr., Prof.",
                    icon: "graduationcap.fill", text: $viewModel.academicTitle, maxLength: 20,
                    isDisabled: viewModel.nameRequiresReKYC || !viewModel.canEditName)
                EditProfileInputField(label: "First Name", placeholder: "Enter your first name",
                    icon: "person.fill", text: $viewModel.firstName,
                    isDisabled: viewModel.nameRequiresReKYC || !viewModel.canEditName)
                EditProfileInputField(label: "Last Name", placeholder: "Enter your last name",
                    icon: "person.fill", text: $viewModel.lastName,
                    isDisabled: viewModel.nameRequiresReKYC || !viewModel.canEditName)
            }

            if viewModel.nameRequiresReKYC && !viewModel.hasPendingNameChangeRequest {
                EditProfileRequestChangeButton(icon: "person.text.rectangle", title: "Request Name Change") {
                    viewModel.showNameChangeRequest = true
                }
            }
        }
    }

    // MARK: - Contact Information Section

    private var contactInformationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(title: "Contact Information")

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                LabeledInputField(label: "Email Address", placeholder: "Enter your email",
                    icon: "envelope.fill", text: $viewModel.email, isEmail: true)

                if let emailError = viewModel.emailValidationMessage {
                    Text(emailError)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LabeledInputField(label: "Phone Number", placeholder: "Enter your phone number",
                    icon: "phone.fill", text: $viewModel.phoneNumber)
            }
        }
    }

    // MARK: - Address Section

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Address",
                showKYCBadge: viewModel.addressRequiresReKYC,
                showLock: !viewModel.canEditAddress && !viewModel.addressRequiresReKYC
            )

            if viewModel.hasPendingAddressChangeRequest, let request = viewModel.pendingAddressChangeRequest {
                EditProfilePendingAddressChange(request: request)
            }

            if viewModel.addressRequiresReKYC && !viewModel.hasPendingAddressChangeRequest {
                EditProfileKYCMessage(
                    icon: "shield.checkered",
                    title: "KYC Compliance Required",
                    message: "Your address has been verified. Changes require re-verification per AML regulations."
                )
            } else if !viewModel.canEditAddress && !viewModel.addressRequiresReKYC {
                EditProfileLockMessage(message: viewModel.addressLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileInputField(label: "Street and Number", placeholder: "Enter street and number",
                    icon: "mappin.circle.fill", text: $viewModel.streetAndNumber,
                    isDisabled: viewModel.addressRequiresReKYC || !viewModel.canEditAddress)
                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    EditProfileInputField(label: "Postal Code", placeholder: "Postal code",
                        icon: "number", text: $viewModel.postalCode, maxLength: 10,
                        isDisabled: viewModel.addressRequiresReKYC || !viewModel.canEditAddress)
                    EditProfileInputField(label: "City", placeholder: "City",
                        icon: "building.2.fill", text: $viewModel.city,
                        isDisabled: viewModel.addressRequiresReKYC || !viewModel.canEditAddress)
                }
                EditProfileInputField(label: "State/Province", placeholder: "Enter state or province",
                    icon: "map.fill", text: $viewModel.state,
                    isDisabled: viewModel.addressRequiresReKYC || !viewModel.canEditAddress)
                EditProfileInputField(label: "Country", placeholder: "Enter country",
                    icon: "globe", text: $viewModel.country,
                    isDisabled: viewModel.addressRequiresReKYC || !viewModel.canEditAddress)
            }

            if viewModel.addressRequiresReKYC && !viewModel.hasPendingAddressChangeRequest {
                EditProfileRequestChangeButton(icon: "arrow.triangle.2.circlepath", title: "Request Address Change") {
                    viewModel.showAddressChangeRequest = true
                }
            }
        }
    }

    // MARK: - Employment Section

    private var employmentSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Employment Information",
                showLock: !viewModel.canEditEmployment
            )

            if !viewModel.canEditEmployment {
                EditProfileLockMessage(message: viewModel.employmentLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileEmploymentPicker(
                    title: "Employment Status",
                    selection: $viewModel.employmentStatus,
                    isDisabled: !viewModel.canEditEmployment
                )
                EditProfileInputField(label: "Annual Income", placeholder: "Enter annual income",
                    icon: "dollarsign.circle.fill", text: $viewModel.income,
                    isDisabled: !viewModel.canEditEmployment)
            }
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            KYCErrorMessageView(message: errorMessage)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        KYCSubmitButton(
            title: "Save Changes",
            isEnabled: viewModel.isFormValid,
            isLoading: viewModel.isLoading,
            action: { Task { await viewModel.saveProfile() } }
        )
    }
}

// MARK: - Preview

#Preview {
    EditProfileView()
}
