import SwiftUI
import UIKit

// MARK: - Image Cache Manager
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB

    private init() {
        cache.totalCostLimit = maxCacheSize
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Optimized Image View
struct OptimizedImageView: View {
    let image: UIImage?
    let placeholder: String
    let maxHeight: CGFloat
    let cornerRadius: CGFloat
    let contentMode: ContentMode

    @State private var cachedImage: UIImage?
    @State private var isLoading = false

    init(
        image: UIImage?,
        placeholder: String = "photo",
        maxHeight: CGFloat = 200,
        cornerRadius: CGFloat = 12,
        contentMode: ContentMode = .fit
    ) {
        self.image = image
        self.placeholder = placeholder
        self.maxHeight = maxHeight
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image = cachedImage ?? image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxHeight: maxHeight)
                    .cornerRadius(cornerRadius)
                    .onAppear {
                        loadImage()
                    }
            } else {
                // Placeholder with loading state
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.inputFieldBackground)
                    .frame(height: maxHeight)
                    .overlay(
                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                            } else {
                                Image(systemName: placeholder)
                                    .font(.system(size: ResponsiveDesign.iconSize() * 1.6))
                                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                            }
                            Text(isLoading ? "Loading..." : "No Image")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                        }
                    )
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let image = image else { return }

        // Generate cache key based on image data
        let cacheKey = generateCacheKey(for: image)

        // Check cache first
        if let cached = ImageCacheManager.shared.getImage(forKey: cacheKey) {
            cachedImage = cached
            return
        }

        // Load image asynchronously
        isLoading = true

        Task {
            // Simulate processing time for large images
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

            await MainActor.run {
                // Compress and cache the image
                let compressedImage = compressImage(image)
                ImageCacheManager.shared.setImage(compressedImage, forKey: cacheKey)
                cachedImage = compressedImage
                isLoading = false
            }
        }
    }

    private func generateCacheKey(for image: UIImage) -> String {
        // Generate a unique key based on image data
        let data = image.jpegData(compressionQuality: 1.0) ?? Data()
        return "image_\(data.hashValue)"
    }

    private func compressImage(_ image: UIImage) -> UIImage {
        // Compress image to reduce memory usage
        let maxSize = CGSize(width: 800, height: 800)
        let aspectRatio = image.size.width / image.size.height

        var newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let compressedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return compressedImage ?? image
    }
}

// MARK: - Lazy Image Grid
struct LazyImageGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let content: (Item) -> Content

    init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

// MARK: - Image Loading States
enum ImageLoadingState {
    case loading
    case loaded(UIImage)
    case failed(Error)
    case empty
}

// MARK: - Async Image Loader
struct AsyncImageLoader: View {
    let imageURL: String?
    let placeholder: String
    let maxHeight: CGFloat
    let cornerRadius: CGFloat

    @State private var loadingState: ImageLoadingState = .loading

    init(
        imageURL: String?,
        placeholder: String = "photo",
        maxHeight: CGFloat = 200,
        cornerRadius: CGFloat = 12
    ) {
        self.imageURL = imageURL
        self.placeholder = placeholder
        self.maxHeight = maxHeight
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            switch loadingState {
            case .loading:
                loadingView
            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .cornerRadius(cornerRadius)
            case .failed:
                errorView
            case .empty:
                emptyView
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.inputFieldBackground)
            .frame(height: maxHeight)
            .overlay(
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentLightBlue))
                    Text("Loading...")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            )
    }

    private var errorView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.inputFieldBackground)
            .frame(height: maxHeight)
            .overlay(
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: ResponsiveDesign.iconSize() * 1.6))
                        .foregroundColor(AppTheme.accentRed)
                    Text("Failed to load")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            )
    }

    private var emptyView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.inputFieldBackground)
            .frame(height: maxHeight)
            .overlay(
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: placeholder)
                        .font(.system(size: ResponsiveDesign.iconSize() * 1.6))
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    Text("No Image")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            )
    }

    private func loadImage() {
        guard let urlString = imageURL, !urlString.isEmpty else {
            loadingState = .empty
            return
        }

        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(forKey: urlString) {
            loadingState = .loaded(cachedImage)
            return
        }

        // Load from URL (simulated for now)
        Task {
            do {
                // Simulate network request
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // In a real app, this would be:
                // let (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
                // let image = UIImage(data: data)!

                // For now, create a placeholder image
                let image = createPlaceholderImage()

                await MainActor.run {
                    // Cache the image
                    ImageCacheManager.shared.setImage(image, forKey: urlString)
                    loadingState = .loaded(image)
                }
            } catch {
                await MainActor.run {
                    loadingState = .failed(error)
                }
            }
        }
    }

    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

        // Draw a simple placeholder
        UIColor.systemBackground.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        return image
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(20)) {
        OptimizedImageView(
            image: nil,
            placeholder: "photo",
            maxHeight: 200,
            cornerRadius: 12
        )

        AsyncImageLoader(
            imageURL: "https://example.com/image.jpg",
            placeholder: "person.fill",
            maxHeight: 150,
            cornerRadius: 8
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
