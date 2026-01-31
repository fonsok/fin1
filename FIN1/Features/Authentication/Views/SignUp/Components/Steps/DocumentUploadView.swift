import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct DocumentUploadView: View {
    @Binding var selectedImage: UIImage?
    @State private var showingCameraPicker = false
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.appServices) private var appServices

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Test Mode Toggle
            if appServices.testModeService.isTestModeEnabled {
                TestModeIndicatorView(
                    onDisable: {
                        appServices.testModeService.disableTestMode()
                        selectedImage = nil
                    }
                )
            }

/*          Text("Adressnachweis hochladen")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
*/
            
            if let image = selectedImage {
                DocumentPreviewView(
                    image: image,
                    onTakeNewPhoto: {
                        showingCameraPicker = true
                    },
                    onSelectOtherFile: {
                        showingDocumentPicker = true
                    }
                )
            } else {
                UploadOptionsView(
                    onTakePhoto: {
                        showingCameraPicker = true
                    },
                    onSelectFile: {
                        showingDocumentPicker = true
                    },
                    onEnableTestMode: {
                        appServices.testModeService.enableTestMode()
                        selectedImage = (appServices.testModeService as? TestModeService)?.sampleAddressDocument
                    }
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
        .sheet(isPresented: $showingCameraPicker) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            PhotoPickerHelper.handleSelection(newItem, binding: $selectedImage)
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let files):
            if let _ = files.first {
                if appServices.testModeService.isTestModeEnabled {
                    selectedImage = (appServices.testModeService as? TestModeService)?.sampleAddressDocument
                } else {
                    // In production, this would be replaced with actual file processing
                    // For now, using sample image in both modes
                    selectedImage = (appServices.testModeService as? TestModeService)?.sampleAddressDocument
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
}

struct TestModeIndicatorView: View {
    let onDisable: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "testtube.2")
                .foregroundColor(AppTheme.accentOrange)
            Text("Test Mode Active")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentOrange)
            Spacer()
            Button("Disable", action: onDisable)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentRed)
        }
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct DocumentPreviewView: View {
    let image: UIImage
    let onTakeNewPhoto: () -> Void
    let onSelectOtherFile: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Use optimized image loading with caching
            OptimizedImageView(
                image: image,
                placeholder: "doc.text",
                maxHeight: 200,
                cornerRadius: 12,
                contentMode: .fit
            )

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button("Neues Foto aufnehmen", action: onTakeNewPhoto)
                    .foregroundColor(AppTheme.accentLightBlue)

                Button("Andere Datei auswählen", action: onSelectOtherFile)
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
    }
}

struct UploadOptionsView: View {
    let onTakePhoto: () -> Void
    let onSelectFile: () -> Void
    let onEnableTestMode: () -> Void
    @Environment(\.appServices) private var appServices

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Wählen Sie eine Upload-Methode:")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Test Mode Button
            if !appServices.testModeService.isTestModeEnabled {
                Button(action: onEnableTestMode, label: {
                    HStack {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.accentOrange)

                        Text("Enable Test Mode")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentOrange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ResponsiveDesign.spacing(8))
                    .background(AppTheme.accentOrange.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(8))
                })
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                UploadOptionButton(
                    icon: "camera.fill",
                    title: "Foto aufnehmen",
                    subtitle: {
                        #if targetEnvironment(simulator)
                        return "Simulator"
                        #else
                        return "Kamera öffnen"
                        #endif
                    }(),
                    action: onTakePhoto
                )

                UploadOptionButton(
                    icon: "doc.text.fill",
                    title: "Datei auswählen",
                    subtitle: "PNG, PDF",
                    action: onSelectFile
                )
            }
        }
    }
}

struct UploadOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(title)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(AppTheme.accentLightBlue, lineWidth: 2)
            )
        })
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DocumentUploadView(selectedImage: .constant(nil))
        .background(AppTheme.screenBackground)
}
