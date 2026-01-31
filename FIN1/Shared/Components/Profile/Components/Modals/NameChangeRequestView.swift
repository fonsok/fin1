import SwiftUI
import PhotosUI

// MARK: - Name Change Request View

/// View for submitting GwG-compliant name change requests.
struct NameChangeRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: NameChangeRequestViewModel

    init() {
        _viewModel = StateObject(wrappedValue: NameChangeRequestViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(20)) {
                        complianceHeader
                        if viewModel.hasPendingRequest {
                            pendingRequestSection
                        } else {
                            currentNameSection
                            reasonSection
                            newNameSection
                            documentsSection
                            declarationsSection
                            errorSection
                            submitSection
                        }
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.vertical, ResponsiveDesign.spacing(20))
                }
            }
            .navigationTitle("Name Change Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Request Submitted", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: { Text(viewModel.successMessage) }
            .alert("Cancel Request?", isPresented: $viewModel.showCancelConfirmation) {
                Button("Keep Request", role: .cancel) {}
                Button("Cancel Request", role: .destructive) { Task { await viewModel.cancelPendingRequest() } }
            } message: { Text("Are you sure you want to cancel your pending name change request?") }
        }
        .onAppear { viewModel.configure(with: appServices) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }.foregroundColor(AppTheme.fontColor)
        }
    }

    private var complianceHeader: some View {
        KYCComplianceHeaderView(
            title: "Name Verification Required",
            description: "Name changes require re-verification under GwG. Please provide official documentation.",
            icon: "person.text.rectangle.fill"
        )
    }

    private var pendingRequestSection: some View {
        Group {
            if let request = viewModel.pendingRequest {
                PendingNameChangeCard(request: request) { viewModel.showCancelConfirmation = true }
            }
        }
    }

    private var currentNameSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "Current Name", badge: "Verified")
            NameDisplayCard(
                salutation: viewModel.currentSalutation, academicTitle: viewModel.currentAcademicTitle,
                firstName: viewModel.currentFirstName, lastName: viewModel.currentLastName
            )
        }
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "Reason for Change")
            NameChangeReasonPicker(selectedReason: $viewModel.selectedReason)
            if viewModel.isSignificantLifeEvent { significantLifeEventBanner }
        }
    }

    private var significantLifeEventBanner: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "star.fill").foregroundColor(AppTheme.accentGreen)
            Text("Priority review: Significant life event recognized.")
                .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentGreen.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var newNameSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "New Name")
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    NameChangeSalutationPicker(selectedSalutation: $viewModel.newSalutation)
                    LabeledInputField(label: "Academic Title", placeholder: "e.g., Dr.",
                        icon: "graduationcap.fill", text: $viewModel.newAcademicTitle)
                }
                LabeledInputField(label: "First Name", placeholder: "Enter first name",
                    icon: "person.fill", text: $viewModel.newFirstName)
                LabeledInputField(label: "Last Name", placeholder: "Enter last name",
                    icon: "person.fill", text: $viewModel.newLastName)
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            KYCSectionHeader(title: "Required Documents")
            Text("Two documents required: Official proof + New government ID")
                .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
            KYCDocumentUploadSection(title: "1. Official Document",
                documentTypes: viewModel.requiredPrimaryDocumentTypes,
                selectedType: $viewModel.selectedPrimaryDocType, selectedImage: $viewModel.primaryDocument,
                documentTypeName: { $0.displayName }, documentTypeDescription: { $0.description },
                documentTypeIcon: { $0.icon })
            KYCDocumentUploadSection(title: "2. New Government ID",
                documentTypes: viewModel.identityDocumentTypes,
                selectedType: $viewModel.selectedIdentityDocType, selectedImage: $viewModel.identityDocument,
                documentTypeName: { $0.displayName }, documentTypeDescription: { $0.description },
                documentTypeIcon: { $0.icon })
        }
    }

    private var declarationsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            KYCSectionHeader(title: "Declarations")
            KYCDeclarationCheckbox(isChecked: $viewModel.userDeclaration,
                text: "I declare all information is true. False info may result in suspension.")
            KYCDeclarationCheckbox(isChecked: $viewModel.acknowledgesRiskProfile,
                text: "I understand my risk profile will be reassessed.")
        }
    }

    @ViewBuilder private var errorSection: some View {
        if let error = viewModel.errorMessage { KYCErrorMessageView(message: error) }
    }

    private var submitSection: some View {
        KYCSubmitButton(title: "Submit Name Change Request", isEnabled: viewModel.isFormValid,
            isLoading: viewModel.isLoading, action: { Task { await viewModel.submitRequest() } })
    }
}

#Preview { NameChangeRequestView() }
