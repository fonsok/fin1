import SwiftUI

// MARK: - Unified InfoBox Component
struct InfoBox: View {
    let title: String
    let value: String
    var backgroundColor: Color = AppTheme.sectionBackground
    var showInfoIcon: Bool = false
    var onInfoTapped: (() -> Void)?
    var onTap: (() -> Void)?
    var titleOpacity: Double = 0.75
    var valueOpacity: Double = 0.85
    var minHeight: CGFloat = 50

    var body: some View {
        Button(action: {
            onTap?()
        }, label: {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        HStack {
                            Text(title)
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.thin)
                                .foregroundColor(AppTheme.fontColor.opacity(titleOpacity))

                            if showInfoIcon {
                                Button(action: {
                                    onInfoTapped?()
                                }, label: {
                                    Image(systemName: "info.circle")
                                        .font(ResponsiveDesign.captionFont())
                                        .foregroundColor(AppTheme.fontColor.opacity(titleOpacity))
                                })
                            }
                        }

                        Text(value)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.regular)
                            .foregroundColor(AppTheme.fontColor.opacity(valueOpacity))
            }
            .padding(ResponsiveDesign.spacing(8))
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(backgroundColor)
            .cornerRadius(ResponsiveDesign.spacing(4))
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flexible TileGrid Component
struct TileGrid: View {
    let tiles: [TileData]
    let columns: Int

    init(tiles: [TileData], columns: Int = 2) {
        self.tiles = tiles
        self.columns = columns
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < tiles.count {
                            InfoBox(
                                title: tiles[index].title,
                                value: tiles[index].value,
                                backgroundColor: tiles[index].backgroundColor,
                                showInfoIcon: tiles[index].showInfoIcon,
                                onInfoTapped: tiles[index].onInfoTapped,
                                onTap: tiles[index].onTap,
                                titleOpacity: tiles[index].titleOpacity,
                                valueOpacity: tiles[index].valueOpacity,
                                minHeight: tiles[index].minHeight
                            )
                        } else {
                            // Empty space to maintain grid alignment
                            Spacer()
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                    }
                }
            }
        }
    }

    private var rows: Int {
        (tiles.count + columns - 1) / columns
    }
}

// MARK: - TileData Structure
struct TileData {
    let title: String
    let value: String
    var backgroundColor: Color = AppTheme.sectionBackground
    var showInfoIcon: Bool = false
    var onInfoTapped: (() -> Void)?
    var onTap: (() -> Void)?
    var titleOpacity: Double = 0.75
    var valueOpacity: Double = 0.85
    var minHeight: CGFloat = 50

    init(title: String, value: String, backgroundColor: Color = AppTheme.sectionBackground, showInfoIcon: Bool = false, onInfoTapped: (() -> Void)? = nil, onTap: (() -> Void)? = nil, titleOpacity: Double = 0.75, valueOpacity: Double = 0.85, minHeight: CGFloat = 50) {
        self.title = title
        self.value = value
        self.backgroundColor = backgroundColor
        self.showInfoIcon = showInfoIcon
        self.onInfoTapped = onInfoTapped
        self.onTap = onTap
        self.titleOpacity = titleOpacity
        self.valueOpacity = valueOpacity
        self.minHeight = minHeight
    }
}

// MARK: - Card Container Component
struct CardContainer<Content: View>: View {
    let position: Int
    let positionPrefix: String
    let content: Content
    let showWatchlistIcon: Bool
    let isInWatchlist: Bool
    let showInvoiceIcon: Bool
    let onPapersheetTapped: (() -> Void)?
    let onWatchlistTapped: (() -> Void)?
    let onInvoiceTapped: (() -> Void)?
    let chevronButton: (() -> AnyView)?

    init(position: Int, positionPrefix: String = "P", showWatchlistIcon: Bool = false, isInWatchlist: Bool = false, showInvoiceIcon: Bool = false, onPapersheetTapped: (() -> Void)? = nil, onWatchlistTapped: (() -> Void)? = nil, onInvoiceTapped: (() -> Void)? = nil, chevronButton: (() -> AnyView)? = nil, @ViewBuilder content: () -> Content) {
        self.position = position
        self.positionPrefix = positionPrefix
        self.showWatchlistIcon = showWatchlistIcon
        self.isInWatchlist = isInWatchlist
        self.showInvoiceIcon = showInvoiceIcon
        self.onPapersheetTapped = onPapersheetTapped
        self.onWatchlistTapped = onWatchlistTapped
        self.onInvoiceTapped = onInvoiceTapped
        self.chevronButton = chevronButton
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(10)) {
                // Left Side - Position Number with optional Papersheet Icon and optional Watchlist Icon
                VStack(spacing: ResponsiveDesign.spacing(30)) {
                    if !positionPrefix.isEmpty {
                        Text("\(positionPrefix) \(position)")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.regular)
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    }

                    if onPapersheetTapped != nil {
                        Button(action: {
                            onPapersheetTapped?()
                        }, label: {
                            Image(systemName: "doc.text.fill")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                        })
                        .buttonStyle(PlainButtonStyle())
                    }

                    if showWatchlistIcon {
                        Button(action: {
                            onWatchlistTapped?()
                        }, label: {
                            Image(systemName: isInWatchlist ? "star.fill" : "star")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                                .foregroundColor(isInWatchlist ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))
                        })
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Chevron button positioned right after the icons, but with extra spacing above it
                    if let chevronButton = chevronButton {
                        chevronButton()
                            .padding(.top, ResponsiveDesign.spacing(30)) // Net 60 spacing above to create breathing room
                    }

                    if showInvoiceIcon {
                        Button(action: {
                            onInvoiceTapped?()
                        }, label: {
                            Image(systemName: "doc.text")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                                .foregroundColor(AppTheme.accentLightBlue)
                        })
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(width: 60)
                .padding(.top, ResponsiveDesign.spacing(8)) // Add padding to center with first row of tiles

                // Right Side - Content (tiles, etc.)
                content
        }
        .padding(ResponsiveDesign.spacing(8))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}











