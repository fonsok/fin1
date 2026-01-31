import SwiftUI
import UIKit

// MARK: - QR Code Views
/// SwiftUI views for displaying QR codes in documents
/// Extracted from QRCodeGenerator.swift to reduce file size

// MARK: - Base QR Code View
struct QRCodeView: View {
    let qrCodeImage: UIImage?
    let size: CGFloat

    init(qrCodeImage: UIImage?, size: CGFloat = 120) {
        self.qrCodeImage = qrCodeImage
        self.size = size
    }

    var body: some View {
        Group {
            if let qrCodeImage = qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Color.white)
                    .cornerRadius(ResponsiveDesign.spacing(8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                // Fallback view if QR code generation fails
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        VStack(spacing: ResponsiveDesign.spacing(4)) {
                            Image(systemName: "qrcode")
                                .font(.system(size: size * 0.3))
                                .foregroundColor(.gray)
                            Text("QR Code")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
}

// MARK: - Invoice QR Code Component
struct InvoiceQRCodeView: View {
    let invoice: Invoice
    @State private var qrCodeImage: UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(8)) {
            // QR Code
            QRCodeView(qrCodeImage: qrCodeImage, size: ResponsiveDesign.spacing(120))

            // QR Code label
            Text("QR Code")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .task {
            generateQRCode()
        }
        .onDisappear {
            // Clear image from memory when view disappears
            qrCodeImage = nil
        }
    }

    private func generateQRCode() {
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                QRCodeGenerator.generateInvoiceQRCode(for: invoice)
            }.value

            await MainActor.run {
                self.qrCodeImage = image
            }
        }
    }
}

// MARK: - Collection Bill QR Code Component
struct CollectionBillQRCodeView: View {
    let trade: TradeOverviewItem
    let displayProperties: TradeStatementDisplayProperties
    @State private var qrCodeImage: UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(8)) {
            // QR Code
            QRCodeView(qrCodeImage: qrCodeImage, size: ResponsiveDesign.spacing(120))

            // QR Code label
            Text("QR Code")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .task {
            generateQRCode()
        }
        .onDisappear {
            // Clear image from memory when view disappears
            qrCodeImage = nil
        }
    }

    private func generateQRCode() {
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                QRCodeGenerator.generateCollectionBillQRCode(for: trade, displayProperties: displayProperties)
            }.value

            await MainActor.run {
                self.qrCodeImage = image
            }
        }
    }
}

// MARK: - Credit Note QR Code Component
struct CreditNoteQRCodeView: View {
    let document: Document
    @State private var qrCodeImage: UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(8)) {
            // QR Code
            QRCodeView(qrCodeImage: qrCodeImage, size: ResponsiveDesign.spacing(120))

            // QR Code label
            Text("QR Code")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.trailing)
        }
        .task {
            generateQRCode()
        }
        .onDisappear {
            // Clear image from memory when view disappears
            qrCodeImage = nil
        }
    }

    private func generateQRCode() {
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                QRCodeGenerator.generateCreditNoteQRCode(for: document)
            }.value

            await MainActor.run {
                self.qrCodeImage = image
            }
        }
    }
}

// MARK: - Investor Collection Bill QR Code Component
struct InvestorCollectionBillQRCodeView: View {
    let investment: Investment
    let documentNumber: String
    @State private var qrCodeImage: UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(8)) {
            // QR Code
            QRCodeView(qrCodeImage: qrCodeImage, size: ResponsiveDesign.spacing(120))

            // QR Code label
            Text("QR Code")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.trailing)
        }
        .task {
            generateQRCode()
        }
        .onDisappear {
            // Clear image from memory when view disappears
            qrCodeImage = nil
        }
    }

    private func generateQRCode() {
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                QRCodeGenerator.generateInvestorCollectionBillQRCode(for: investment, documentNumber: documentNumber)
            }.value

            await MainActor.run {
                self.qrCodeImage = image
            }
        }
    }
}
