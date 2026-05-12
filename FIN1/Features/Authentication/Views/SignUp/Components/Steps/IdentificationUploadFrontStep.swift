import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// Import UI components and managers
// Note: These components are now in the UI subfolder

struct IdentificationUploadFrontStep: View {
    let identificationType: IdentificationType
    @Binding var passportFrontImage: UIImage?
    @Binding var idCardFrontImage: UIImage?
    @State private var showingCameraPicker = false
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Access the test mode manager
    @Environment(\.appServices) private var appServices

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            Text("Vorderseite hochladen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("Bitte laden Sie die Vorderseite Ihres \(identificationType.displayName)es hoch")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)

            // Test Mode Toggle
            if appServices.testModeService.isTestModeEnabled {
                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Test Mode Active")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentOrange)
                    Spacer()
                    Button("Disable") {
                        appServices.testModeService.disableTestMode()
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                }
                .padding(ResponsiveDesign.spacing(8))
                .background(AppTheme.accentOrange.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }

            // Image Preview or Upload Options
            if let image = identificationType == .passport ? passportFrontImage : idCardFrontImage {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(ResponsiveDesign.spacing(12))

                    HStack(spacing: ResponsiveDesign.spacing(16)) {
                        Button("Neues Foto aufnehmen") {
                            showingCameraPicker = true
                        }
                        .foregroundColor(AppTheme.accentLightBlue)

                        Button("Andere Datei auswählen") {
                            showingDocumentPicker = true
                        }
                        .foregroundColor(AppTheme.accentLightBlue)
                    }
                }
            } else {
                // Upload Options
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Text("Wählen Sie eine Upload-Methode:")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Test Mode Button
                    if !appServices.testModeService.isTestModeEnabled {
                        Button(action: {
                            appServices.testModeService.enableTestMode()
                            // Use sample images for testing
                            if identificationType == .passport {
                                passportFrontImage = (appServices.testModeService as? TestModeService)?.samplePassportImage
                            } else {
                                idCardFrontImage = (appServices.testModeService as? TestModeService)?.sampleIDCardImage
                            }
                        }) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.accentOrange)

                                Text("Enable Test Mode")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentOrange)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(ResponsiveDesign.spacing(8))
                            .background(AppTheme.accentOrange.opacity(0.1))
                            .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    HStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Camera Button
                        Button(action: {
                            showingCameraPicker = true
                        }) {
                            VStack(spacing: ResponsiveDesign.spacing(12)) {
                                Image(systemName: "camera.fill")
                                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                                    .foregroundColor(AppTheme.accentLightBlue)

                                Text("Foto aufnehmen")
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.accentLightBlue)

                                #if targetEnvironment(simulator)
                                Text("Simulator")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.accentOrange)
                                #else
                                Text("Kamera öffnen")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                                #endif
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: ResponsiveDesign.spacing(120))
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                    .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // File Picker Button
                        Button(action: {
                            showingDocumentPicker = true
                        }) {
                            VStack(spacing: ResponsiveDesign.spacing(12)) {
                                Image(systemName: "doc.text.fill")
                                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                                    .foregroundColor(AppTheme.accentLightBlue)

                                Text("Datei auswählen")
                                    .font(ResponsiveDesign.headlineFont())
                                    .foregroundColor(AppTheme.accentLightBlue)

                                Text("PNG, PDF")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: ResponsiveDesign.spacing(120))
                            .background(AppTheme.sectionBackground)
                            .cornerRadius(ResponsiveDesign.spacing(12))
                            .overlay(
                                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                    .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Instructions
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Hinweise für ein gutes Foto:")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    InfoBullet(text: "Halten Sie das Dokument flach und ruhig")
                    InfoBullet(text: "Stellen Sie sicher, dass alle Ecken sichtbar sind")
                    InfoBullet(text: "Vermeiden Sie Reflexionen und Schatten")
                    InfoBullet(text: "Nutzen Sie ausreichend Licht")
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPicker(selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        if identificationType == .passport {
                            passportFrontImage = image
                        } else {
                            idCardFrontImage = image
                        }
                    }
                }
            ))
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            PhotoPickerHelper.handleSelection(newItem, binding: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        if identificationType == .passport {
                            passportFrontImage = image
                        } else {
                            idCardFrontImage = image
                        }
                    }
                }
            ))
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    // Handle file import - convert to UIImage
                    // For testing purposes, we'll use our sample image
                    if appServices.testModeService.isTestModeEnabled {
                        if identificationType == .passport {
                            passportFrontImage = (appServices.testModeService as? TestModeService)?.samplePassportImage
                        } else {
                            idCardFrontImage = (appServices.testModeService as? TestModeService)?.sampleIDCardImage
                        }
                    } else {
                        // This would need actual implementation for file processing
                        print("Selected file: \(file)")

                        // For now, just use the sample image in real mode too
                        // In production, this would be replaced with actual file processing
                        if identificationType == .passport {
                            passportFrontImage = (appServices.testModeService as? TestModeService)?.samplePassportImage
                        } else {
                            idCardFrontImage = (appServices.testModeService as? TestModeService)?.sampleIDCardImage
                        }
                    }
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }
}

#Preview {
    IdentificationUploadFrontStep(
        identificationType: .passport,
        passportFrontImage: .constant(nil),
        idCardFrontImage: .constant(nil)
    )
    .background(AppTheme.screenBackground)
}
