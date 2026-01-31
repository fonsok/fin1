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
                        SummaryRow(label: "Account Type", value: signUpData.accountType.displayName, icon: "person.2.fill")
                        SummaryRow(label: "User Role", value: signUpData.userRole.displayName, icon: "person.crop.circle.fill")
                    }
                    
                    SummarySection(title: "Contact Information") {
                        SummaryRow(label: "Email", value: signUpData.email, icon: "envelope.fill")
                        SummaryRow(label: "Username", value: signUpData.username, icon: "person.circle.fill")
                        SummaryRow(label: "Phone", value: signUpData.phoneNumber, icon: "phone.fill")
                    }
                    
                    SummarySection(title: "Personal Information") {
                        SummaryRow(label: "Kundennummer", value: signUpData.customerId, icon: "number.circle.fill")
                        SummaryRow(label: "Salutation", value: signUpData.salutation.displayName, icon: "person.fill")
                        if !signUpData.academicTitle.isEmpty {
                            SummaryRow(label: "Academic Title", value: signUpData.academicTitle, icon: "graduationcap.fill")
                        }
                        SummaryRow(label: "First Name", value: signUpData.firstName, icon: "person.fill")
                        SummaryRow(label: "Last Name", value: signUpData.lastName, icon: "person.fill")
                        SummaryRow(label: "Street & Number", value: signUpData.streetAndNumber, icon: "house.fill")
                        SummaryRow(label: "Postal Code", value: signUpData.postalCode, icon: "envelope.fill")
                        SummaryRow(label: "City", value: signUpData.city, icon: "building.2.fill")
                        SummaryRow(label: "State", value: signUpData.state, icon: "map.fill")
                        SummaryRow(label: "Country", value: signUpData.country, icon: "globe")
                        SummaryRow(label: "Date of Birth", value: signUpData.dateOfBirth.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                        SummaryRow(label: "Place of Birth", value: signUpData.placeOfBirth, icon: "mappin.circle.fill")
                        SummaryRow(label: "Country of Birth", value: signUpData.countryOfBirth, icon: "flag.fill")
                    }
                    
                    SummarySection(title: "Citizenship & Tax") {
                        SummaryRow(label: "US Citizen", value: signUpData.isNotUSCitizen ? "No" : "Yes", icon: "flag.filled.and.flag.crossed")
                        SummaryRow(label: "Nationality", value: signUpData.nationality, icon: "flag.fill")
                        SummaryRow(label: "Tax Number", value: signUpData.taxNumber, icon: "doc.text.fill")
                        if !signUpData.additionalResidenceCountry.isEmpty {
                            SummaryRow(label: "Additional Tax Residence", value: signUpData.additionalResidenceCountry, icon: "building.2.crossed.fill")
                        }
                    }
                    
                    // Risk Assessment Section
                    SummarySection(title: "Risk Assessment") {
                        RiskClassSummaryRow(signUpData: signUpData)
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
