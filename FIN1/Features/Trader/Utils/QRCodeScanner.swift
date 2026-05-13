@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import UIKit

// MARK: - QR Code Scanner
/// Handles scanning QR codes to extract invoice information
final class QRCodeScanner: NSObject, ObservableObject, @unchecked Sendable {
    @Published var scannedData: String = ""
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?

    private var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.fin1.qrcode.session")

    override init() {
        super.init()
        self.setupCaptureSession()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let captureSession = captureSession else { return }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            self.errorMessage = "Camera not available"
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            let appError = error.toAppError()
            self.errorMessage = "Failed to create video input: \(appError.errorDescription ?? "An error occurred")"
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            self.errorMessage = "Cannot add video input to capture session"
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            self.errorMessage = "Cannot add metadata output to capture session"
            return
        }
    }

    func startScanning() {
        self.sessionQueue.async { [weak self] in
            guard let session = self?.captureSession, !session.isRunning else { return }
            session.startRunning()
        }

        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
            self?.errorMessage = nil
        }
    }

    func stopScanning() {
        self.sessionQueue.async { [weak self] in
            guard let session = self?.captureSession, session.isRunning else { return }
            session.stopRunning()
        }

        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
        }
    }

    @MainActor
    func setupPreviewLayer(in view: UIView) {
        guard let captureSession = captureSession else { return }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }

    @MainActor
    func removePreviewLayer() {
        self.previewLayer?.removeFromSuperlayer()
        self.previewLayer = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRCodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            DispatchQueue.main.async {
                self.scannedData = stringValue
                self.stopScanning()
            }
        }
    }
}

// MARK: - Invoice QR Code Parser
extension QRCodeScanner {

    /// Parses scanned QR code data to extract invoice information
    /// - Parameter qrData: The scanned QR code data
    /// - Returns: Parsed invoice information or nil if parsing fails
    func parseInvoiceQRData(_ qrData: String) -> InvoiceQRInfo? {
        print("🔧 DEBUG: Parsing QR code data: \(qrData.prefix(100))...")

        // Try to parse as JSON first
        if let jsonData = qrData.data(using: .utf8) {
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return self.parseJSONInvoiceData(jsonObject)
                }
            } catch {
                print("❌ DEBUG: Failed to parse QR data as JSON: \(error.localizedDescription)")
            }
        }

        // Fallback to simple pipe-separated format
        return self.parseSimpleInvoiceData(qrData)
    }

    private func parseJSONInvoiceData(_ jsonObject: [String: Any]) -> InvoiceQRInfo? {
        guard let type = jsonObject["type"] as? String,
              type == "\(LegalIdentity.documentPrefix)_INVOICE" || type == "FIN1_INVOICE" else {
            print("❌ DEBUG: Invalid QR code type")
            return nil
        }

        let invoiceNumber = jsonObject["invoice_number"] as? String ?? ""
        let invoiceId = jsonObject["invoice_id"] as? String ?? ""
        let customerName = jsonObject["customer_name"] as? String ?? ""
        let totalAmount = jsonObject["total_amount"] as? String ?? ""
        let status = jsonObject["status"] as? String ?? ""

        return InvoiceQRInfo(
            type: type,
            invoiceNumber: invoiceNumber,
            invoiceId: invoiceId,
            customerName: customerName,
            totalAmount: totalAmount,
            status: status,
            rawData: jsonObject
        )
    }

    private func parseSimpleInvoiceData(_ qrData: String) -> InvoiceQRInfo? {
        let components = qrData.components(separatedBy: "|")

        guard components.count >= 5 else {
            print("❌ DEBUG: Invalid simple QR code format")
            return nil
        }

        return InvoiceQRInfo(
            type: components[0],
            invoiceNumber: components[1],
            invoiceId: components[2],
            customerName: components[4],
            totalAmount: components[3],
            status: "unknown",
            rawData: ["simple_format": qrData]
        )
    }
}

// MARK: - Invoice QR Info Model
struct InvoiceQRInfo {
    let type: String
    let invoiceNumber: String
    let invoiceId: String
    let customerName: String
    let totalAmount: String
    let status: String
    let rawData: [String: Any]

    var formattedTotalAmount: String {
        if let amount = Double(totalAmount) {
            return amount.formattedAsLocalizedCurrency()
        }
        return self.totalAmount
    }

    var isValid: Bool {
        return !self.invoiceNumber.isEmpty && !self.invoiceId.isEmpty && !self.customerName.isEmpty
    }
}

// MARK: - SwiftUI QR Scanner View
struct QRCodeScannerView: UIViewRepresentable {
    @ObservedObject var scanner: QRCodeScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        self.scanner.setupPreviewLayer(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = scanner.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Clean up when view is removed
    }
}
