import Foundation

// MARK: - InvoiceService Backend Integration Extension
/// Backend integration for InvoiceService
/// Extracted to separate file to keep InvoiceService.swift under 400 lines

private struct CreateInvoiceResponse: Decodable {
    let invoiceId: String
    let invoiceNumber: String
    let status: String
}

extension InvoiceService {

    // MARK: - Backend Integration

    func saveServiceChargeInvoiceToBackend(
        _ invoice: Invoice,
        apiClient: any ParseAPIClientProtocol
    ) async {
        do {
            let amounts = extractServiceChargeAmounts(from: invoice)
            let customerInfo = buildCustomerInfoDictionary(from: invoice)
            let investmentIds = extractInvestmentIds(from: invoice)

            var parameters: [String: Any] = [
                "invoiceNumber": invoice.invoiceNumber,
                "grossServiceChargeAmount": invoice.totalAmount,
                "netServiceChargeAmount": amounts.net,
                "vatAmount": amounts.vat,
                "vatRate": amounts.vatRate,
                "customerInfo": customerInfo
            ]

            if let batchId = invoice.tradeId {
                parameters["batchId"] = batchId
            }

            if !investmentIds.isEmpty {
                parameters["investmentIds"] = investmentIds
            }

            let response = try await callCreateInvoiceCloudFunction(
                apiClient: apiClient,
                parameters: parameters
            )

            print("✅ InvoiceService: Service Charge Invoice saved to backend")
            print("   📋 Invoice Number: \(response.invoiceNumber)")
            print("   🆔 Invoice ID: \(response.invoiceId)")
        } catch {
            print("⚠️ InvoiceService: Failed to save Service Charge Invoice to backend: \(error.localizedDescription)")
            print("   📄 Invoice will remain in local storage only")
        }
    }

    // MARK: - Backend Integration Helpers

    private func extractServiceChargeAmounts(from invoice: Invoice) -> (net: Double, vat: Double, vatRate: Double) {
        let netServiceCharge = invoice.items
            .first { $0.itemType == .serviceCharge }?.totalAmount ?? 0
        let vatAmount = invoice.items
            .first { $0.itemType == .vat }?.totalAmount ?? 0
        let vatRate = vatAmount > 0 && netServiceCharge > 0
            ? (vatAmount / netServiceCharge) * 100
            : 19.0

        return (net: netServiceCharge, vat: vatAmount, vatRate: vatRate)
    }

    private func buildCustomerInfoDictionary(from invoice: Invoice) -> [String: String] {
        return [
            "name": invoice.customerInfo.name,
            "address": invoice.customerInfo.address,
            "city": invoice.customerInfo.city,
            "postalCode": invoice.customerInfo.postalCode,
            "email": "", // Customer email not stored in CustomerInfo
            "customerNumber": invoice.customerInfo.customerNumber
        ]
    }

    private func extractInvestmentIds(from invoice: Invoice) -> [String] {
        guard let serviceChargeItem = invoice.items.first(where: { $0.itemType == .serviceCharge }) else {
            // Fallback to batchId if no service charge item found
            return invoice.tradeId.map { [$0] } ?? []
        }

        let description = serviceChargeItem.description
        let lines = description.components(separatedBy: "\n")

        guard lines.count > 1 else {
            // Fallback to batchId if no IDs in description
            return invoice.tradeId.map { [$0] } ?? []
        }

        var investmentIds: [String] = []
        for line in lines.dropFirst() {
            let id = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            if !id.isEmpty {
                investmentIds.append(id)
            }
        }

        // Fallback to batchId if no investment IDs found
        if investmentIds.isEmpty, let batchId = invoice.tradeId {
            return [batchId]
        }

        return investmentIds
    }

    private func callCreateInvoiceCloudFunction(
        apiClient: any ParseAPIClientProtocol,
        parameters: [String: Any]
    ) async throws -> CreateInvoiceResponse {
        return try await apiClient.callFunction(
            "createServiceChargeInvoice",
            parameters: parameters
        )
    }
}
