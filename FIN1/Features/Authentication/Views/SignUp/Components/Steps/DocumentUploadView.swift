import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
            if self.appServices.testModeService.isTestModeEnabled {
                TestModeIndicatorView(
                    onDisable: {
                        self.appServices.testModeService.disableTestMode()
                        self.selectedImage = nil
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
                        self.showingCameraPicker = true
                    },
                    onSelectOtherFile: {
                        self.showingDocumentPicker = true
                    }
                )
            } else {
                UploadOptionsView(
                    onTakePhoto: {
                        self.showingCameraPicker = true
                    },
                    onSelectFile: {
                        self.showingDocumentPicker = true
                    },
                    onEnableTestMode: {
                        self.appServices.testModeService.enableTestMode()
                        self.selectedImage = (self.appServices.testModeService as? TestModeService)?.sampleAddressDocument
                    }
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
        .sheet(isPresented: self.$showingCameraPicker) {
            CameraPicker(selectedImage: self.$selectedImage)
        }
        .photosPicker(
            isPresented: self.$showingPhotoPicker,
            selection: self.$selectedPhotoItem,
            matching: .images
        )
        .onChange(of: self.selectedPhotoItem) { _, newItem in
            PhotoPickerHelper.handleSelection(newItem, binding: self.$selectedImage)
        }
        .fileImporter(
            isPresented: self.$showingDocumentPicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            self.handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let files):
            if let _ = files.first {
                if self.appServices.testModeService.isTestModeEnabled {
                    self.selectedImage = (self.appServices.testModeService as? TestModeService)?.sampleAddressDocument
                } else {
                    // In production, this would be replaced with actual file processing
                    // For now, using sample image in both modes
                    self.selectedImage = (self.appServices.testModeService as? TestModeService)?.sampleAddressDocument
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
            Button("Disable", action: self.onDisable)
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
                image: self.image,
                placeholder: "doc.text",
                maxHeight: 200,
                cornerRadius: 12,
                contentMode: .fit
            )

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button("Neues Foto aufnehmen", action: self.onTakeNewPhoto)
                    .foregroundColor(AppTheme.accentLightBlue)

                Button("Andere Datei auswählen", action: self.onSelectOtherFile)
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
            if !self.appServices.testModeService.isTestModeEnabled {
                Button(action: self.onEnableTestMode, label: {
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
                    action: self.onTakePhoto
                )

                UploadOptionButton(
                    icon: "doc.text.fill",
                    title: "Datei auswählen",
                    subtitle: "PNG, PDF",
                    action: self.onSelectFile
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
        Button(action: self.action, label: {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 1.6))
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(self.title)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(self.subtitle)
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
