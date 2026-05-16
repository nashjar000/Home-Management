// Haptics to use later if there's time

import UIKit

enum Haptics {
    static func light() {
        DispatchQueue.main.async {
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred()
        }
    }

    static func medium() {
        DispatchQueue.main.async {
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.prepare()
            g.impactOccurred()
        }
    }

    static func heavy() {
        DispatchQueue.main.async {
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.prepare()
            g.impactOccurred()
        }
    }

    static func success() {
        DispatchQueue.main.async {
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        }
    }

    static func warning() {
        DispatchQueue.main.async {
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.warning)
        }
    }

    static func error() {
        DispatchQueue.main.async {
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.error)
        }
    }
}
