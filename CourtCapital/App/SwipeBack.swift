import UIKit

/// The edition draws its own headers and hides the navigation bar, which switches off both ways
/// of going back by swiping: from the screen's edge, and (since iOS 26) from anywhere on the page.
/// This turns both on again whenever there is a screen to go back to.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
        if #available(iOS 26.0, *) {
            interactiveContentPopGestureRecognizer?.delegate = self
        }
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard viewControllers.count > 1, transitionCoordinator == nil else { return false }
        guard gestureRecognizer !== interactivePopGestureRecognizer else { return true }
        // A swipe that starts inside the page only goes back when it heads right, more sideways
        // than down, so scrolling the page keeps working.
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return velocity.x > 0 && velocity.x > abs(velocity.y)
    }
}
