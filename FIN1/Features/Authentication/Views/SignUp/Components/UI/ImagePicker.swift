import PhotosUI
import SwiftUI
import UIKit

// MARK: - Image Picker (Legacy - Deprecated)
/// Legacy wrapper for backward compatibility
/// Prefer using PhotoPicker (PhotosPicker) for photo library and CameraPicker for camera
@available(iOS, deprecated: 16.0, message: "Use PhotoPicker with PhotosPicker for photo library and CameraPicker for camera")
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    // Access the test mode manager
    @Environment(\.appServices) private var appServices

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        // If in test mode and trying to use camera, automatically return a sample image
        if self.appServices.testModeService.isTestModeEnabled && self.sourceType == .camera {
            // Use a slight delay to simulate camera opening and then auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectedImage = (self.appServices.testModeService as? TestModeService)?.samplePassportImage
                self.dismiss()
            }
        }

        picker.sourceType = self.sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
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

#Preview {
    Text("ImagePicker Preview")
        .onTapGesture {
            // This would show the image picker in a real app
        }
}
