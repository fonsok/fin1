import SwiftUI

// Import Forms components
// Note: These components are now in the Forms subfolder

struct PersonalInfoStep: View {
    @Binding var salutation: Salutation
    @Binding var academicTitle: String
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var streetAndNumber: String
    @Binding var postalCode: String
    @Binding var city: String
    @Binding var state: String
    @Binding var country: String
    @Binding var dateOfBirth: Date
    @Binding var placeOfBirth: String
    @Binding var countryOfBirth: String
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            VStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Persönliche Daten")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                
                Text("(lt. Ausweisdokumenten)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Salutation and Academic Title (side by side)
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                CustomPicker(
                    title: "Anrede",
                    selection: $salutation,
                    labelColor: Color(red: 0.96, green: 0.96, blue: 0.96) // #f5f5f5
                )
                
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Akad. Titel")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)
                    
                    TextField("Optional", text: $academicTitle)
                        .font(ResponsiveDesign.isCompactDevice() ? .title3 : .title2)
                        .foregroundColor(AppTheme.inputFieldText)
                        .padding(ResponsiveDesign.spacing(16))
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
                }
            }
            
            // Name Fields
            LabeledInputField(
                label: "Vorname",
                placeholder: "Vorname eingeben",
                icon: "person.fill",
                text: $firstName
            )
            
            LabeledInputField(
                label: "Name",
                placeholder: "Name eingeben",
                icon: "person.fill",
                text: $lastName
            )
            
            // Address Fields
            LabeledInputField(
                label: "Straße und Hausnummer",
                placeholder: "Straße und Hausnummer eingeben",
                icon: "house.fill",
                text: $streetAndNumber
            )
            
            LabeledInputField(
                label: "PLZ",
                placeholder: "PLZ eingeben",
                icon: "envelope.fill",
                text: $postalCode
            )
            
            LabeledInputField(
                label: "Wohnort",
                placeholder: "Wohnort eingeben",
                icon: "building.2.fill",
                text: $city
            )
            
            LabeledInputField(
                label: "Bundesland",
                placeholder: "Bundesland eingeben",
                icon: "map.fill",
                text: $state
            )
            
            LabeledInputField(
                label: "Land",
                placeholder: "Land eingeben",
                icon: "globe",
                text: $country
            )
            
            // Birth Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Geburtstag")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
                
                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .foregroundColor(AppTheme.inputFieldText)
                    .padding()
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
            }
            
            LabeledInputField(
                label: "Geburtsort",
                placeholder: "Geburtsort eingeben",
                icon: "mappin.circle.fill",
                text: $placeOfBirth
            )
            
            LabeledInputField(
                label: "Geburtsland",
                placeholder: "Geburtsland eingeben",
                icon: "flag.fill",
                text: $countryOfBirth
            )
        }
    }
}

#Preview {
    PersonalInfoStep(
        salutation: .constant(.mr),
        academicTitle: .constant("Dr."),
        firstName: .constant("Max"),
        lastName: .constant("Mustermann"),
        streetAndNumber: .constant("Musterstraße 123"),
        postalCode: .constant("12345"),
        city: .constant("Musterstadt"),
        state: .constant("Bayern"),
        country: .constant("Deutschland"),
        dateOfBirth: .constant(Date()),
        placeOfBirth: .constant("München"),
        countryOfBirth: .constant("Deutschland")
    )
    .background(AppTheme.screenBackground)
}
