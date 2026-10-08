import SwiftUI
import UIKit

enum Preferences {
    static let appearance = "appearance"
    static let morningNotification = "morningNotification"
    static let deliveryMinutes = "deliveryMinutes"

    /// 05:05: five minutes after the edition is due.
    static let defaultDeliveryMinutes = 5 * 60 + 5
}

enum Appearance: String, CaseIterable, Identifiable {
    case day, night, automatic

    var id: Self { self }

    var title: String {
        switch self {
        case .day: "Day"
        case .night: "Night"
        case .automatic: "Automatic"
        }
    }

    var note: String {
        switch self {
        case .day: "The morning paper: ivory stock, navy ink."
        case .night: "The library at night: green leather, cream type, brass."
        case .automatic: "Follows the iPhone’s light and dark setting."
        }
    }

    private var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .day: .light
        case .night: .dark
        case .automatic: .unspecified
        }
    }

    /// Sets the style on the windows directly; `preferredColorScheme(nil)` does not reliably
    /// hand control back to the system once an explicit scheme has been set.
    @MainActor
    func apply(animated: Bool) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            let change = { window.overrideUserInterfaceStyle = interfaceStyle }
            if animated {
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: change)
            } else {
                change()
            }
        }
    }
}
