import Foundation

extension UserService {

    /// Applies onboarding risk class to the in-memory user and notifies observers.
    func applyRiskTolerance(_ riskTolerance: Int) async {
        await MainActor.run { [weak self] in
            guard let self, var user = self.currentUser else { return }
            user.riskTolerance = riskTolerance
            self.currentUser = user
            NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        }
    }
}
