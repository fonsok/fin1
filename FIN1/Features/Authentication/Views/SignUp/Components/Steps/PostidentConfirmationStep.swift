import SwiftUI

struct PostidentConfirmationStep: View {
    @Binding var identificationConfirmed: Bool
    @State private var showingPostidentWebView = false
    @State private var postidentCode: String = "\(LegalIdentity.documentPrefix)-\(Int.random(in: 100000...999999))"

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Postident Identifikation")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("Identifikation über Postident Verfahren")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)

            // Postident Information
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.accentLightBlue)
                    .padding(.bottom, 8)

                Text("So funktioniert Postident")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                VStack(alignment: .leading, spacing: 12) {
                    InfoBullet(text: "Postident ist ein Identifikationsverfahren der Deutschen Post")
                    InfoBullet(text: "Sie können sich in einer Postfiliale oder per Video-Chat identifizieren")
                    InfoBullet(text: "Bringen Sie Ihren Ausweis oder Reisepass mit")
                    InfoBullet(text: "Die Identifikation ist kostenlos")
                }
                .padding(.bottom, 8)

                // Postident Code
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text("Ihr persönlicher Postident-Code:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text(postidentCode)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentLightBlue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.accentLightBlue.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Postident Options
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Identifikationsoptionen")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Video-Ident Option
                Button(action: {
                    showingPostidentWebView = true
                }) {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accentLightBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video-Ident")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Online per Video-Chat identifizieren")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Post-Ident Option
                Button(action: {
                    // Open PDF or instructions for post office identification
                }) {
                    HStack {
                        Image(systemName: "building.columns")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accentLightBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Postfilial-Ident")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("In einer Postfiliale identifizieren")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Print Postident Coupon
                Button(action: {
                    // Generate and print Postident coupon
                }) {
                    HStack {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accentLightBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Postident-Coupon drucken")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)

                            Text("Coupon ausdrucken und zur Post mitnehmen")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding()
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))

            // Confirmation
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Button(action: { identificationConfirmed.toggle() }, label: {
                    HStack {
                        InteractiveElement(
                            isSelected: identificationConfirmed,
                            type: .confirmationCircle
                        )

                        Text("Ich habe den Postident-Prozess gestartet oder werde ihn später durchführen")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                })
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
        .sheet(isPresented: $showingPostidentWebView) {
            // In a real app, this would be a WebView showing the Postident video identification process
            PostidentWebViewPlaceholder(postidentCode: postidentCode)
        }
    }
}

// Placeholder for WebView (in a real app, this would be a WebView component)
struct PostidentWebViewPlaceholder: View {
    let postidentCode: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(20)) {
                Image(systemName: "video.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.accentLightBlue)
                    .padding()

                Text("Video-Ident Prozess")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)

                Text("In einer echten App würde hier der Video-Ident Prozess gestartet werden.")
                    .multilineTextAlignment(.center)
                    .padding()

                Text("Ihr Postident-Code:")
                    .font(ResponsiveDesign.headlineFont())

                Text(postidentCode)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .padding()
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(8))

                Spacer()

                Button("Schließen") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.accentLightBlue)
                .foregroundColor(AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(12))
                .padding()
            }
            .padding()
            .navigationBarTitle("Video-Identifikation", displayMode: .inline)
            .navigationBarItems(trailing: Button("Schließen") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    PostidentConfirmationStep(identificationConfirmed: .constant(false))
        .background(AppTheme.screenBackground)
}
