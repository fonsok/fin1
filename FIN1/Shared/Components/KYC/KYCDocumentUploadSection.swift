import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KYC Document Upload Section

/// Reusable document upload section for KYC verification forms
struct KYCDocumentUploadSection<DocumentType: Hashable>: View {
    let title: String
    let documentTypes: [DocumentType]
    @Binding var selectedType: DocumentType
    @Binding var selectedImage: UIImage?
    let documentTypeName: (DocumentType) -> String
    let documentTypeDescription: (DocumentType) -> String
    let documentTypeIcon: (DocumentType) -> String

    @State private var showingCameraPicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            KYCSectionHeader(title: self.title)

            self.documentTypePicker
            self.documentTypeInfo
            self.uploadArea
        }
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
            isPresented: self.$showingFilePicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            self.handleFileImport(result)
        }
    }

    // MARK: - Document Type Picker

    private var documentTypePicker: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Document Type")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Menu {
                ForEach(self.documentTypes, id: \.self) { type in
                    Button(action: { self.selectedType = type }) {
                        Label(self.documentTypeName(type), systemImage: self.documentTypeIcon(type))
                    }
                }
            } label: {
                HStack {
                    Image(systemName: self.documentTypeIcon(self.selectedType))
                        .foregroundColor(AppTheme.accentLightBlue)
                    Text(self.documentTypeName(self.selectedType))
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

    // MARK: - Document Type Info

    private var documentTypeInfo: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(AppTheme.accentLightBlue)
            Text(self.documentTypeDescription(self.selectedType))
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Upload Area

    @ViewBuilder
    private var uploadArea: some View {
        if let image = selectedImage {
            self.documentPreview(image: image)
        } else {
            self.uploadButtons
        }
    }

    private func documentPreview(image: UIImage) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: ResponsiveDesign.spacing(200))
                .cornerRadius(ResponsiveDesign.spacing(12))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                        .stroke(AppTheme.accentGreen, lineWidth: 2)
                )

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button(action: { self.showingCameraPicker = true }) {
                    Label("Retake", systemImage: "camera.fill")
                        .font(ResponsiveDesign.captionFont())
                }
                .buttonStyle(.bordered)

                Button(action: { self.showingPhotoPicker = true }) {
                    Label("Replace", systemImage: "photo.fill")
                        .font(ResponsiveDesign.captionFont())
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: { self.selectedImage = nil }) {
                    Label("Remove", systemImage: "trash.fill")
                        .font(ResponsiveDesign.captionFont())
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: ResponsiveDesign.spacing(6)) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.accentGreen)
                Text("Document uploaded")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentGreen)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var uploadButtons: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                self.uploadOptionButton(
                    icon: "camera.fill",
                    title: "Take Photo",
                    action: { self.showingCameraPicker = true }
                )

                self.uploadOptionButton(
                    icon: "photo.fill",
                    title: "Photo Library",
                    action: { self.showingPhotoPicker = true }
                )

                self.uploadOptionButton(
                    icon: "folder.fill",
                    title: "Files",
                    action: { self.showingFilePicker = true }
                )
            }

            Text("Upload a clear photo or scan of your document")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundColor(AppTheme.fontColor.opacity(0.3))
        )
    }

    private func uploadOptionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    // MARK: - File Import Handler

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    self.selectedImage = image
                }
            } catch {
                print("Error loading file: \(error)")
            }

        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    KYCDocumentUploadSection(
        title: "Proof of Address",
        documentTypes: AddressVerificationDocumentType.allCases,
        selectedType: .constant(.utilityBill),
        selectedImage: .constant(nil),
        documentTypeName: { $0.displayName },
        documentTypeDescription: { $0.description },
        documentTypeIcon: { $0.icon }
    )
    .padding()
}





