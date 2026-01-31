import Foundation

/// Server-driven FAQ category model (id/slug/title/icon)
struct FAQCategoryContent: Identifiable, Hashable, Codable {
    /// Parse `objectId` (server) or `slug` (bundled fallback)
    let id: String
    let slug: String
    let title: String
    let icon: String
    let sortOrder: Int

    init(id: String, slug: String, title: String, icon: String, sortOrder: Int) {
        self.id = id
        self.slug = slug
        self.title = title
        self.icon = icon
        self.sortOrder = sortOrder
    }
}

