import SwiftUI

// Import RiskClass components
// Note: These components are now in the RiskClass subfolder

struct SummaryStep: View {
    let signUpData: SignUpData
    let coordinator: SignUpCoordinator?
    
    init(signUpData: SignUpData, coordinator: SignUpCoordinator? = nil) {
        self.signUpData = signUpData
        self.coordinator = coordinator
    }
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Text("Review Your Profile")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            
            Text("Please review your information before completing registration")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)
            
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    SummarySection(title: "Account Information") {
                        SummaryRow(label: "Account Type", value: self.signUpData.accountType.displayName, icon: "person.2.fill")
                        SummaryRow(label: "User Role", value: self.signUpData.userRole.displayName, icon: "person.crop.circle.fill")
                    }
                    
                    SummarySection(title: "Contact Information") {
                        SummaryRow(label: "Email", value: self.signUpData.email, icon: "envelope.fill")
                        SummaryRow(label: "Username", value: self.signUpData.username, icon: "person.circle.fill")
                        SummaryRow(label: "Phone", value: self.signUpData.phoneNumber, icon: "phone.fill")
                    }
                    
                    SummarySection(title: "Personal Information") {
                        SummaryRow(label: "Kundennummer", value: self.signUpData.customerNumber, icon: "number.circle.fill")
                        SummaryRow(label: "Salutation", value: self.signUpData.salutation.displayName, icon: "person.fill")
                        if !self.signUpData.academicTitle.isEmpty {
                            SummaryRow(label: "Academic Title", value: self.signUpData.academicTitle, icon: "graduationcap.fill")
                        }
                        SummaryRow(label: "First Name", value: self.signUpData.firstName, icon: "person.fill")
                        SummaryRow(label: "Last Name", value: self.signUpData.lastName, icon: "person.fill")
                        SummaryRow(label: "Street & Number", value: self.signUpData.streetAndNumber, icon: "house.fill")
                        SummaryRow(label: "Postal Code", value: self.signUpData.postalCode, icon: "envelope.fill")
                        SummaryRow(label: "City", value: self.signUpData.city, icon: "building.2.fill")
                        SummaryRow(label: "State", value: self.signUpData.state, icon: "map.fill")
                        SummaryRow(label: "Country", value: self.signUpData.country, icon: "globe")
                        SummaryRow(
                            label: "Date of Birth",
                            value: self.signUpData.dateOfBirth.formatted(date: .abbreviated, time: .omitted),
                            icon: "calendar"
                        )
                        SummaryRow(label: "Place of Birth", value: self.signUpData.placeOfBirth, icon: "mappin.circle.fill")
                        SummaryRow(label: "Country of Birth", value: self.signUpData.countryOfBirth, icon: "flag.fill")
                    }
                    
                    SummarySection(title: "Citizenship & Tax") {
                        SummaryRow(
                            label: "US Citizen",
                            value: self.signUpData.isNotUSCitizen ? "No" : "Yes",
                            icon: "flag.filled.and.flag.crossed"
                        )
                        SummaryRow(label: "Nationality", value: self.signUpData.nationality, icon: "flag.fill")
                        SummaryRow(label: "Tax Number", value: self.signUpData.taxNumber, icon: "doc.text.fill")
                        if !self.signUpData.additionalResidenceCountry.isEmpty {
                            SummaryRow(
                                label: "Additional Tax Residence",
                                value: self.signUpData.additionalResidenceCountry,
                                icon: "building.2.crossed.fill"
                            )
                        }
                    }
                    
                    // Risk Assessment Section
                    SummarySection(title: "Risk Assessment") {
                        RiskClassSummaryRow(signUpData: self.signUpData)
                    }
                }
            }
            .onAppear {
                // calculatedRiskClass is now a computed property, no need to set it manually
            }
            
            // Final Confirmation
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentGreen)
                        .font(ResponsiveDesign.headlineFont())
                    
                    Text("Alle Informationen sind korrekt")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                    
                    Spacer()
                }
                
                Text("Mit klicken auf \"Weiter\" bestätigen Sie, dass alle oben genannten Informationen korrekt sind.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.accentGreen.opacity(0.1))
            .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(AppTheme.accentGreen.opacity(0.3), lineWidth: 1)
            )
            
            // Note: Complete Registration button is handled by SignUpNavigationButtons
            // for Risk Class 7 users, which will trigger the welcome page
        }
        // Note: Welcome page is now handled by SignUpView for Risk Class 7 users
    }
}

#Preview {
    SummaryStep(signUpData: SignUpData(), coordinator: SignUpCoordinator())
        .background(AppTheme.screenBackground)
}
