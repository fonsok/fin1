import SwiftUI

// MARK: - Pending Name Change View

struct EditProfilePendingNameChange: View {
    let request: NameChangeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.bodyFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text("Name Change Pending")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Requested: \(self.request.newFullName)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(1)

                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: self.request.reason.icon)
                            .font(ResponsiveDesign.captionFont())
                        Text("Reason: \(self.request.reason.displayName)")
                            .font(ResponsiveDesign.captionFont())
                    }
                    .foregroundColor(AppTheme.accentOrange)

                    Text(
                        "Submitted \(self.request.submittedAt.formatted(date: .abbreviated, time: .omitted)) • \(self.request.status.displayName)"
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }

                Spacer()

                if self.request.status == .pending || self.request.status == .underReview {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Pending Address Change View

struct EditProfilePendingAddressChange: View {
    let request: AddressChangeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(AppTheme.accentOrange)
                    .font(ResponsiveDesign.bodyFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text("Address Change Pending")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Requested: \(self.request.newFormattedAddress)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .lineLimit(2)

                    Text(
                        "Submitted \(self.request.submittedAt.formatted(date: .abbreviated, time: .omitted)) • \(self.request.status.displayName)"
                    )
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
                }

                Spacer()

                if self.request.status == .pending || self.request.status == .underReview {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Previews

#Preview("Pending Name Change") {
    let request = NameChangeRequest(
        userId: "user123",
        currentSalutation: "Mr.",
        currentAcademicTitle: "",
        currentFirstName: "John",
        currentLastName: "Doe",
        newSalutation: "Mr.",
        newAcademicTitle: "Dr.",
        newFirstName: "John",
        newLastName: "Smith",
        reason: .marriage,
        primaryDocumentType: .marriageCertificate,
        identityDocumentType: .newIdCard,
        userDeclaration: true,
        acknowledgesRiskProfileUpdate: true
    )
    EditProfilePendingNameChange(request: request)
        .padding()
}





