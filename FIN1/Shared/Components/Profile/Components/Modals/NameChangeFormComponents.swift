import SwiftUI

// MARK: - Name Display Card

/// Displays the current name in a card format
struct NameDisplayCard: View {
    let salutation: String
    let academicTitle: String
    let firstName: String
    let lastName: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            if !self.salutation.isEmpty { Text(self.salutation).font(ResponsiveDesign.captionFont()) }
            Text("\(self.academicTitle.isEmpty ? "" : "\(self.academicTitle) ")\(self.firstName) \(self.lastName)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
        }
        .foregroundColor(AppTheme.fontColor.opacity(0.9))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Name Change Reason Picker

/// Picker for selecting the reason for name change
struct NameChangeReasonPicker: View {
    @Binding var selectedReason: NameChangeReason

    var body: some View {
        Menu {
            ForEach(NameChangeReason.allCases, id: \.self) { reason in
                Button(action: { self.selectedReason = reason }) {
                    Label(reason.displayName, systemImage: reason.icon)
                }
            }
        } label: {
            HStack {
                Image(systemName: self.selectedReason.icon)
                    .foregroundColor(AppTheme.accentLightBlue)
                Text(self.selectedReason.displayName)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
    }
}

// MARK: - Salutation Picker

/// Picker for selecting salutation in name change form
struct NameChangeSalutationPicker: View {
    @Binding var selectedSalutation: String
    private let salutations = ["Mr.", "Ms.", "Mrs.", "Dr.", "Prof.", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Salutation")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Menu {
                ForEach(self.salutations, id: \.self) { sal in
                    Button(sal.isEmpty ? "None" : sal) { self.selectedSalutation = sal }
                }
            } label: {
                HStack {
                    Text(self.selectedSalutation.isEmpty ? "Select" : self.selectedSalutation)
                        .foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
        .frame(width: ResponsiveDesign.spacing(100))
    }
}

// MARK: - Pending Name Change Card

/// Card showing pending name change request status
struct PendingNameChangeCard: View {
    let request: NameChangeRequest
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Pending Request")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                Spacer()
                KYCRequestStatusBadge(status: self.request.status.displayName, color: .orange)
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("New Name: \(self.request.newFullName)")
                Text("Reason: \(self.request.reason.displayName)")
                Text("Submitted: \(self.request.submittedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.8))

            if self.request.canCancel {
                Button(action: self.onCancel) {
                    Text("Cancel Request")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentRed)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Previews

#Preview("Name Display") {
    NameDisplayCard(salutation: "Mr.", academicTitle: "Dr.", firstName: "John", lastName: "Doe")
        .padding()
}

#Preview("Reason Picker") {
    NameChangeReasonPicker(selectedReason: .constant(.marriage))
        .padding()
}





