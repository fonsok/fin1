import Foundation

// MARK: - Customer Support Service - Account Modifications Extension
/// Extension handling account modification operations with compliance logging

extension CustomerSupportService {

    // MARK: - Address Change

    func requestAddressChange(customerId: String, newAddress: CSAddressChangeInput) async throws -> ChangeRequest {
        try await validatePermission(.updateCustomerAddress)

        guard let customer = mockCustomers.first(where: { $0.customerId == customerId }) else {
            throw CustomerSupportError.customerNotFound
        }

        let previousAddress = customer.formattedAddress ?? "Unbekannt"
        let newAddressString = "\(newAddress.streetAndNumber), \(newAddress.postalCode) \(newAddress.city), \(newAddress.country)"

        await auditService.logModificationWithCompliance(
            agentId: currentAgentId,
            agentRole: currentAgentRole,
            customerId: customerId,
            permission: .updateCustomerAddress,
            fieldName: "Adresse",
            previousValue: previousAddress,
            newValue: newAddressString,
            complianceEventType: .addressChange
        )

        return ChangeRequest(
            id: UUID().uuidString,
            requestType: .address,
            customerId: customerId,
            requestedBy: currentAgentId,
            status: .pending,
            previousValue: previousAddress,
            newValue: newAddressString,
            reason: newAddress.reason,
            createdAt: Date(),
            reviewedBy: nil,
            reviewedAt: nil,
            reviewNotes: nil
        )
    }

    // MARK: - Name Change

    func requestNameChange(customerId: String, newName: CSNameChangeInput) async throws -> ChangeRequest {
        try await validatePermission(.updateCustomerName)

        guard let customer = mockCustomers.first(where: { $0.customerId == customerId }) else {
            throw CustomerSupportError.customerNotFound
        }

        let previousName = customer.fullName
        var newNameParts: [String] = []
        if let title = newName.academicTitle { newNameParts.append(title) }
        if let first = newName.firstName { newNameParts.append(first) }
        if let last = newName.lastName { newNameParts.append(last) }
        let newNameString = newNameParts.isEmpty ? previousName : newNameParts.joined(separator: " ")

        await auditService.logModificationWithCompliance(
            agentId: currentAgentId,
            agentRole: currentAgentRole,
            customerId: customerId,
            permission: .updateCustomerName,
            fieldName: "Name",
            previousValue: previousName,
            newValue: newNameString,
            complianceEventType: .nameChange
        )

        return ChangeRequest(
            id: UUID().uuidString,
            requestType: .name,
            customerId: customerId,
            requestedBy: currentAgentId,
            status: .pending,
            previousValue: previousName,
            newValue: newNameString,
            reason: newName.reason,
            createdAt: Date(),
            reviewedBy: nil,
            reviewedAt: nil,
            reviewNotes: nil
        )
    }

    // MARK: - Password Reset

    func initiatePasswordReset(customerId: String) async throws {
        try await validatePermission(.resetCustomerPassword)

        await logAction(
            .resetCustomerPassword,
            customerId: customerId,
            description: "Passwort-Zurücksetzung eingeleitet"
        )

        let event = ComplianceEvent(
            eventType: .passwordReset,
            agentId: currentAgentId,
            customerId: customerId,
            description: "Passwort-Zurücksetzung durch Kundenservice",
            severity: .low,
            requiresReview: false
        )
        await auditService.logComplianceEvent(event)
    }

    // MARK: - Account Unlock

    func unlockAccount(customerId: String, reason: String) async throws {
        try await validatePermission(.unlockCustomerAccount)

        await logAction(
            .unlockCustomerAccount,
            customerId: customerId,
            description: "Konto entsperrt: \(reason)"
        )

        let event = ComplianceEvent(
            eventType: .accountUnlock,
            agentId: currentAgentId,
            customerId: customerId,
            description: "Kontoentsperrung: \(reason)",
            severity: .medium,
            requiresReview: true
        )
        await auditService.logComplianceEvent(event)
    }
}

