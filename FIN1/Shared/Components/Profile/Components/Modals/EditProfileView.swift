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
                        self.personalInformationSection
                        self.contactInformationSection
                        self.addressSection
                        self.employmentSection
                        self.errorSection
                        self.saveButton
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { self.dismiss() }
                        .foregroundColor(AppTheme.fontColor)
                }
            }
            .alert("Profile Updated", isPresented: self.$viewModel.showSuccessAlert) {
                Button("OK") { self.dismiss() }
            } message: {
                Text("Your profile has been successfully updated.")
            }
            .sheet(isPresented: self.$viewModel.showAddressChangeRequest) {
                AddressChangeRequestView()
            }
            .sheet(isPresented: self.$viewModel.showNameChangeRequest) {
                NameChangeRequestView()
            }
        }
        .onAppear { self.viewModel.configure(with: self.appServices) }
    }

    // MARK: - Personal Information Section

    private var personalInformationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Personal Information",
                showKYCBadge: self.viewModel.nameRequiresReKYC,
                showLock: !self.viewModel.canEditName && !self.viewModel.nameRequiresReKYC
            )

            if self.viewModel.hasPendingNameChangeRequest, let request = viewModel.pendingNameChangeRequest {
                EditProfilePendingNameChange(request: request)
            }

            if self.viewModel.nameRequiresReKYC && !self.viewModel.hasPendingNameChangeRequest {
                EditProfileKYCMessage(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "GwG Compliance Required",
                    message: "Your identity has been verified. Name changes require re-verification per GwG."
                )
            } else if !self.viewModel.canEditName && !self.viewModel.nameRequiresReKYC {
                EditProfileLockMessage(message: self.viewModel.nameLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileSalutationPicker(
                    title: "Salutation",
                    selection: self.$viewModel.salutation,
                    isDisabled: self.viewModel.nameRequiresReKYC || !self.viewModel.canEditName
                )
                EditProfileInputField(label: "Academic Title", placeholder: "e.g., Dr., Prof.",
                                      icon: "graduationcap.fill", text: self.$viewModel.academicTitle, maxLength: 20,
                                      isDisabled: self.viewModel.nameRequiresReKYC || !self.viewModel.canEditName)
                EditProfileInputField(label: "First Name", placeholder: "Enter your first name",
                                      icon: "person.fill", text: self.$viewModel.firstName,
                                      isDisabled: self.viewModel.nameRequiresReKYC || !self.viewModel.canEditName)
                EditProfileInputField(label: "Last Name", placeholder: "Enter your last name",
                                      icon: "person.fill", text: self.$viewModel.lastName,
                                      isDisabled: self.viewModel.nameRequiresReKYC || !self.viewModel.canEditName)
            }

            if self.viewModel.nameRequiresReKYC && !self.viewModel.hasPendingNameChangeRequest {
                EditProfileRequestChangeButton(icon: "person.text.rectangle", title: "Request Name Change") {
                    self.viewModel.showNameChangeRequest = true
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
                                  icon: "envelope.fill", text: self.$viewModel.email, isEmail: true)

                if let emailError = viewModel.emailValidationMessage {
                    Text(emailError)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LabeledInputField(label: "Phone Number", placeholder: "Enter your phone number",
                                  icon: "phone.fill", text: self.$viewModel.phoneNumber)
            }
        }
    }

    // MARK: - Address Section

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Address",
                showKYCBadge: self.viewModel.addressRequiresReKYC,
                showLock: !self.viewModel.canEditAddress && !self.viewModel.addressRequiresReKYC
            )

            if self.viewModel.hasPendingAddressChangeRequest, let request = viewModel.pendingAddressChangeRequest {
                EditProfilePendingAddressChange(request: request)
            }

            if self.viewModel.addressRequiresReKYC && !self.viewModel.hasPendingAddressChangeRequest {
                EditProfileKYCMessage(
                    icon: "shield.checkered",
                    title: "KYC Compliance Required",
                    message: "Your address has been verified. Changes require re-verification per AML regulations."
                )
            } else if !self.viewModel.canEditAddress && !self.viewModel.addressRequiresReKYC {
                EditProfileLockMessage(message: self.viewModel.addressLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileInputField(label: "Street and Number", placeholder: "Enter street and number",
                                      icon: "mappin.circle.fill", text: self.$viewModel.streetAndNumber,
                                      isDisabled: self.viewModel.addressRequiresReKYC || !self.viewModel.canEditAddress)
                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    EditProfileInputField(label: "Postal Code", placeholder: "Postal code",
                                          icon: "number", text: self.$viewModel.postalCode, maxLength: 10,
                                          isDisabled: self.viewModel.addressRequiresReKYC || !self.viewModel.canEditAddress)
                    EditProfileInputField(label: "City", placeholder: "City",
                                          icon: "building.2.fill", text: self.$viewModel.city,
                                          isDisabled: self.viewModel.addressRequiresReKYC || !self.viewModel.canEditAddress)
                }
                EditProfileInputField(label: "State/Province", placeholder: "Enter state or province",
                                      icon: "map.fill", text: self.$viewModel.state,
                                      isDisabled: self.viewModel.addressRequiresReKYC || !self.viewModel.canEditAddress)
                EditProfileInputField(label: "Country", placeholder: "Enter country",
                                      icon: "globe", text: self.$viewModel.country,
                                      isDisabled: self.viewModel.addressRequiresReKYC || !self.viewModel.canEditAddress)
            }

            if self.viewModel.addressRequiresReKYC && !self.viewModel.hasPendingAddressChangeRequest {
                EditProfileRequestChangeButton(icon: "arrow.triangle.2.circlepath", title: "Request Address Change") {
                    self.viewModel.showAddressChangeRequest = true
                }
            }
        }
    }

    // MARK: - Employment Section

    private var employmentSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            EditProfileSectionHeader(
                title: "Employment Information",
                showLock: !self.viewModel.canEditEmployment
            )

            if !self.viewModel.canEditEmployment {
                EditProfileLockMessage(message: self.viewModel.employmentLockMessage)
            }

            VStack(spacing: ResponsiveDesign.spacing(16)) {
                EditProfileEmploymentPicker(
                    title: "Employment Status",
                    selection: self.$viewModel.employmentStatus,
                    isDisabled: !self.viewModel.canEditEmployment
                )
                EditProfileInputField(label: "Annual Income", placeholder: "Enter annual income",
                                      icon: "dollarsign.circle.fill", text: self.$viewModel.income,
                                      isDisabled: !self.viewModel.canEditEmployment)
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
            isEnabled: self.viewModel.isFormValid,
            isLoading: self.viewModel.isLoading,
            action: { Task { await self.viewModel.saveProfile() } }
        )
    }
}

// MARK: - Preview

#Preview {
    EditProfileView()
}
