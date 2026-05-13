import Foundation

// MARK: - Downloads Folder Utility
/// Handles saving files to the user's Downloads folder
final class DownloadsFolderUtility {

    // MARK: - Public Methods

    /// Saves data to the Downloads folder
    /// - Parameters:
    ///   - data: The data to save
    ///   - fileName: The name of the file (without extension)
    ///   - fileExtension: The file extension (default: "pdf")
    /// - Returns: The URL where the file was saved
    /// - Throws: AppError if saving fails
    static func saveToDownloads(_ data: Data, fileName: String, fileExtension: String = "pdf") async throws -> URL {
        do {
            let downloadsURL = try getDownloadsURL()

            // Ensure the Downloads directory exists
            try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true, attributes: nil)
            print("🔧 DEBUG: Downloads directory ensured at: \(downloadsURL.path)")

            let fileURL = downloadsURL.appendingPathComponent("\(fileName).\(fileExtension)")

            print("🔧 DEBUG: Attempting to save file to: \(fileURL.path)")
            print("🔧 DEBUG: Data size: \(data.count) bytes")

            try data.write(to: fileURL)
            print("📁 File saved to Downloads: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to save file to Downloads: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw AppError.serviceError(.operationFailed)
        }
    }

    /// Gets the Downloads folder URL
    /// - Returns: The Downloads folder URL
    /// - Throws: AppError if Downloads folder is not accessible
    static func getDownloadsURL() throws -> URL {
        let fileManager = FileManager.default

        // For iOS, use Documents directory with Downloads subfolder
        // .downloadsDirectory doesn't exist in iOS, so we create our own
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsURL = documentsURL.appendingPathComponent("Downloads")

        print("🔧 DEBUG: Using Downloads URL: \(downloadsURL.path)")

        // Create Downloads directory if it doesn't exist
        if !fileManager.fileExists(atPath: downloadsURL.path) {
            do {
                try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created Downloads folder: \(downloadsURL.path)")
            } catch {
                print("❌ Failed to create Downloads folder: \(error.localizedDescription)")
                throw AppError.serviceError(.operationFailed)
            }
        } else {
            print("🔧 DEBUG: Downloads directory already exists")
        }

        return downloadsURL
    }

    /// Checks if Downloads folder is accessible
    /// - Returns: True if accessible, false otherwise
    static func isDownloadsAccessible() -> Bool {
        do {
            _ = try self.getDownloadsURL()
            return true
        } catch {
            return false
        }
    }

    /// Gets the path to Downloads folder as a string
    /// - Returns: The Downloads folder path
    static func getDownloadsPath() -> String {
        do {
            return try self.getDownloadsURL().path
        } catch {
            return "Downloads folder not accessible"
        }
    }
}

// MARK: - AppError Extension for Downloads
extension AppError {
    static let downloadsNotAccessible = AppError.serviceError(.operationFailed)
    static let fileSaveFailed = AppError.serviceError(.operationFailed)
}
