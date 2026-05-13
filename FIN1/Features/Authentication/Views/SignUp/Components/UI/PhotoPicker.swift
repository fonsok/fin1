import PhotosUI
import SwiftUI
import UIKit

// MARK: - Photo Picker Helper
/// Helper functions for PhotosPicker integration
/// Replaces UIImagePickerController for photo library access
enum PhotoPickerHelper {
    /// Handles the selected PhotosPickerItem and converts it to UIImage
    static func handleSelection(_ item: PhotosPickerItem?, binding: Binding<UIImage?>) {
        guard let item = item else {
            binding.wrappedValue = nil
            return
        }

        Task {
            // Load image data from PhotosPickerItem
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    binding.wrappedValue = image
                }
            }
        }
    }
}

// MARK: - Camera Picker
/// Minimal camera wrapper - still requires UIKit for UIImagePickerController
/// This is the minimal UIKit usage needed for camera access
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        // Test mode handling
        if self.appServices.testModeService.isTestModeEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectedImage = (self.appServices.testModeService as? TestModeService)?.samplePassportImage
                self.dismiss()
            }
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                self.parent.selectedImage = image
            }
            self.parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.dismiss()
        }
    }
}
