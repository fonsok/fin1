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
                        self.headerSection
                        self.quickContactSection
                        self.supportFormSection
                        self.contactInfoSection
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(16))
                    .padding(.bottom, ResponsiveDesign.spacing(16))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { self.dismiss() }
                        .foregroundColor(AppTheme.accentLightBlue)
                }
            }
            .alert("Request Submitted", isPresented: self.$viewModel.showSubmitSuccess) {
                Button("OK") { self.viewModel.resetForm() }
            } message: {
                if let ticketNumber = viewModel.createdTicketNumber {
                    Text("Your ticket \(ticketNumber) has been created. We'll respond \(self.viewModel.estimatedResponseTime.lowercased()).")
                } else {
                    Text("Thank you for contacting us. We'll respond to your request \(self.viewModel.estimatedResponseTime.lowercased()).")
                }
            }
            .alert("Error", isPresented: self.$viewModel.showSubmitError) {
                Button("OK") {}
            } message: { Text(self.viewModel.errorMessage) }
            .alert("Call Support", isPresented: self.$viewModel.showCallConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Call") { if let url = viewModel.phoneURL() { self.openURL(url) } }
            } message: {
                Text("Call \(self.viewModel.supportPhone)?\n\nSupport hours: \(self.viewModel.supportHours)")
            }
            .alert("Live Chat Unavailable", isPresented: self.$viewModel.showLiveChatUnavailable) {
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
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
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
                    if let url = viewModel.emailURL() { self.openURL(url) }
                }
                ContactMethodButton(title: "Phone", icon: "phone.fill", color: AppTheme.accentGreen) {
                    self.viewModel.initiatePhoneCall()
                }
                ContactMethodButton(title: "Chat", icon: "bubble.left.and.bubble.right.fill", color: AppTheme.accentOrange) {
                    self.viewModel.startLiveChat()
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
            self.sectionHeader(title: "Submit a Request", icon: "doc.text.fill", color: AppTheme.accentLightBlue)
            self.categoryPicker
            self.subjectField
            self.messageField
            self.screenshotToggle
            self.submitButton
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Category").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
            Menu {
                ForEach(self.viewModel.availableCategories) { category in
                    Button(action: { self.viewModel.selectedCategory = category }) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: self.viewModel.selectedCategory.icon)
                        .foregroundColor(SupportCategoryHelper.color(for: self.viewModel.selectedCategory))
                    Text(self.viewModel.selectedCategory.rawValue).font(ResponsiveDesign.bodyFont()).foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Image(systemName: "chevron.down").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            HStack {
                Text("Priority:").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text(self.viewModel.selectedCategory.priority.rawValue)
                    .font(ResponsiveDesign.captionFont()).fontWeight(.medium)
                    .foregroundColor(SupportCategoryHelper.priorityColor(for: self.viewModel.selectedCategory.priority))
                Text("• Response: \(self.viewModel.estimatedResponseTime)")
                    .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
    }

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Subject").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
            TextField("Brief description of your issue", text: self.$viewModel.subject)
                .textFieldStyle(SettingsTextFieldStyle())
        }
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Message").font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.fontColor.opacity(0.7))
                Spacer()
                Text("\(self.viewModel.message.count)/1000")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.viewModel.message.count > 900 ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.5))
            }
            TextEditor(text: self.$viewModel.message)
                .frame(minHeight: 120)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .foregroundColor(AppTheme.fontColor)
                .scrollContentBackground(.hidden)
                .onChange(of: self.viewModel.message) { _, newValue in
                    if newValue.count > 1_000 { self.viewModel.message = String(newValue.prefix(1_000)) }
                }
            if self.viewModel.message.count < 10 && !self.viewModel.message.isEmpty {
                Text("Please provide more details (at least 10 characters)")
                    .font(ResponsiveDesign.captionFont()).foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    private var screenshotToggle: some View {
        Toggle(isOn: self.$viewModel.attachScreenshot) {
            HStack {
                Image(systemName: "camera.fill").foregroundColor(AppTheme.fontColor.opacity(0.6))
                Text("Include screenshot").font(ResponsiveDesign.bodyFont()).foregroundColor(AppTheme.fontColor)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentLightBlue))
    }

    private var submitButton: some View {
        Button(action: { self.viewModel.submitRequest() }) {
            HStack {
                if self.viewModel.isSubmitting {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Request").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.viewModel.isFormValid ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(!self.viewModel.isFormValid || self.viewModel.isSubmitting)
    }

    // MARK: - Contact Info Section

    private var contactInfoSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            self.sectionHeader(title: "Contact Information", icon: "info.circle.fill", color: AppTheme.accentOrange)
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ContactInfoRow(icon: "envelope.fill", label: "Email", value: self.viewModel.supportEmail, color: AppTheme.accentLightBlue)
                ContactInfoRow(icon: "phone.fill", label: "Phone (US)", value: self.viewModel.supportPhone, color: AppTheme.accentGreen)
                ContactInfoRow(
                    icon: "phone.fill",
                    label: "Phone (DE)",
                    value: self.viewModel.supportPhoneGermany,
                    color: AppTheme.accentGreen
                )
                ContactInfoRow(icon: "clock.fill", label: "Hours", value: self.viewModel.supportHours, color: AppTheme.accentOrange)
            }
            self.helpCenterTip
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
