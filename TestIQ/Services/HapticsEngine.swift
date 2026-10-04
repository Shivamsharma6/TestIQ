import Foundation
import UIKit

/// Typed wrapper over the system feedback generators, so call sites read as intent
/// ("a correct answer happened") instead of as API calls.
@MainActor
final class HapticsEngine {
    static let shared = HapticsEngine()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    /// Call when the run starts; keeps the Taptic Engine warm so the first answer is not
    /// late because the hardware was still spinning up.
    func prepare() {
        self.light.prepare()
        self.medium.prepare()
        self.notification.prepare()
    }

    func tap() {
        self.selection.selectionChanged()
    }

    func tick() {
        self.soft.impactOccurred(intensity: 0.5)
    }

    func correct() {
        self.medium.impactOccurred(intensity: 0.85)
    }

    func correctWithStreak(_ streak: Int) {
        // Escalate with the combo so a long run is felt, not just seen.
        let intensity = min(1.0, 0.7 + Double(streak) * 0.08)
        self.medium.impactOccurred(intensity: intensity)
    }

    func wrong() {
        self.rigid.impactOccurred(intensity: 0.9)
    }

    func success() {
        self.notification.notificationOccurred(.success)
    }

    func failure() {
        self.notification.notificationOccurred(.error)
    }

    func levelCleared() {
        self.notification.notificationOccurred(.success)
        self.heavy.impactOccurred(intensity: 0.7)
    }

    func timeWarning() {
        self.light.impactOccurred(intensity: 1.0)
    }
}