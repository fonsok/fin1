import SwiftUI

// MARK: - Contact Support View
/// User interface for contacting customer support through various channels
/// Creates actual support tickets via CustomerSupportService
struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: ContactSupportViewModel

    init() {
        // ViewModel will be reconfigured with appServices in .onAppear
        // Using .live as initial value, then reconfigured via environment
        let services = AppServices.live
        _viewModel = StateObject(wrappedValue: ContactSupportViewModel(
            userService: services.userService,
            customerSupportService: services.customerSupportService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        headerSection
                        quickContactSection
                        supportFormSection
                        contactInfoSection
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .alert("Request Submitted", isPresented: $viewModel.showSubmitSuccess) {
                Button("OK") { viewModel.resetForm() }
            } message: {
                if let ticketNumber = viewModel.createdTicketNumber {
                    Text("Your ticket \(ticketNumber) has been created. We'll respond \(viewModel.estimatedResponseTime.lowercased()).")
                } else {
                    Text("Thank you for contacting us. We'll respond to your request \(viewModel.estimatedResponseTime.lowercased()).")
                }
            }
            .alert("Error", isPresented: $viewModel.showSubmitError) {
                Button("OK") {}
            } message: { Text(viewModel.errorMessage) }
            .alert("Call Support", isPresented: $viewModel.showCallConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Call") { if let url = viewModel.phoneURL() { openURL(url) } }
            } message: {
                Text("Call \(viewModel.supportPhone)?\n\nSupport hours: \(viewModel.supportHours)")
            }
            .alert("Live Chat Unavailable", isPresented: $viewModel.showLiveChatUnavailable) {
                Button("OK") {}
            } message: {
                Text("Live chat is currently unavailable. Please try email or phone support, or submit a support request.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "message.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentGreen)
            Text("Contact Support")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Text("We're here to help. Choose how you'd like to reach us.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, ResponsiveDesign.spacing(16))
    }

    // MARK: - Quick Contact Section

    private var quickContactSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Quick Contact").font(ResponsiveDesign.headlineFont()).foregroundColor(AppTheme.fontColor)
                Spacer()
            }
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                ContactMethodButton(title: "Email", icon: "envelope.fill", color: AppTheme.accentLightBlue) {
                    if let url = viewModel.emailURL() { openURL(url) }
                }
                ContactMethodButton(title: "Phone", icon: "phone.fill", color: AppTheme.accentGreen) {
                    viewModel.initiatePhoneCall()
                }
                ContactMethodButton(title: "Chat", icon: "bubble.left.and.bubble.right.fill", color: AppTheme.accentOrange) {
                    viewModel.startLiveChat()
                }
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Support Form Section

    private var supportFormSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            sectionHeader(title: "Submit a Request", icon: "doc.text.fill", color: AppTheme.accentLightBlue)
            categoryPicker
            subjectField
            messageField
            screenshotToggle
            submitButton
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Category").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
            Menu {
                ForEach(viewModel.availableCategories) { category in
                    Button(action: { viewModel.selectedCategory = category }) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedCategory.icon)
                        .foregroundColor(SupportCategoryHelper.color(for: viewModel.selectedCategory))
                    Text(viewModel.selectedCategory.rawValue).font(ResponsiveDesign.bodyFont()).foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Image(systemName: "chevron.down").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            HStack {
                Text("Priority:").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text(viewModel.selectedCategory.priority.rawValue)
                    .font(ResponsiveDesign.captionFont()).fontWeight(.medium)
                    .foregroundColor(SupportCategoryHelper.priorityColor(for: viewModel.selectedCategory.priority))
                Text("• Response: \(viewModel.estimatedResponseTime)")
                    .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
    }

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Subject").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
            TextField("Brief description of your issue", text: $viewModel.subject)
                .textFieldStyle(SettingsTextFieldStyle())
        }
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Message").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
                Spacer()
                Text("\(viewModel.message.count)/1000")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(viewModel.message.count > 900 ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.5))
            }
            TextEditor(text: $viewModel.message)
                .frame(minHeight: 120)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .foregroundColor(AppTheme.fontColor)
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.message) { _, newValue in
                    if newValue.count > 1000 { viewModel.message = String(newValue.prefix(1000)) }
                }
            if viewModel.message.count < 10 && !viewModel.message.isEmpty {
                Text("Please provide more details (at least 10 characters)")
                    .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    private var screenshotToggle: some View {
        Toggle(isOn: $viewModel.attachScreenshot) {
            HStack {
                Image(systemName: "camera.fill").foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text("Include screenshot").font(ResponsiveDesign.bodyFont()).foregroundColor(AppTheme.fontColor)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
    }

    private var submitButton: some View {
        Button(action: { viewModel.submitRequest() }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Request").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(!viewModel.isFormValid || viewModel.isSubmitting)
    }

    // MARK: - Contact Info Section

    private var contactInfoSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            sectionHeader(title: "Contact Information", icon: "info.circle.fill", color: AppTheme.accentOrange)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ContactInfoRow(icon: "envelope.fill", label: "Email", value: viewModel.supportEmail, color: AppTheme.accentLightBlue)
                ContactInfoRow(icon: "phone.fill", label: "Phone (US)", value: viewModel.supportPhone, color: AppTheme.accentGreen)
                ContactInfoRow(icon: "phone.fill", label: "Phone (DE)", value: viewModel.supportPhoneGermany, color: AppTheme.accentGreen)
                ContactInfoRow(icon: "clock.fill", label: "Hours", value: viewModel.supportHours, color: AppTheme.accentOrange)
            }
            helpCenterTip
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var helpCenterTip: some View {
        HStack {
            Image(systemName: "lightbulb.fill").foregroundColor(AppTheme.accentOrange).font(ResponsiveDesign.bodyFont())
            Text("Check our Help Center for quick answers to common questions.")
                .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Helper Methods

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).font(ResponsiveDesign.headlineFont()).foregroundColor(color).frame(width: 24)
            Text(title).font(ResponsiveDesign.headlineFont()).foregroundColor(AppTheme.fontColor)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContactSupportView()
        .environment(\.appServices, AppServices.live)
}
