import SwiftUI
import UIKit

/// Dismisses the keyboard when the user taps anywhere that is not a text input.
///
/// A window-level recogniser is used instead of a SwiftUI tap gesture on each screen: a gesture on a
/// container also fires when a text field is tapped, which would close the keyboard the moment it opens.
/// `cancelsTouchesInView = false` means buttons and rows still receive their taps.
@MainActor
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private weak var installedWindow: UIWindow?
    private var observing = false

    /// Safe to call repeatedly. Also re-attaches if the key window changes (for example after a scene reconnect).
    func install() {
        attach()
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.attach() }
        }
    }

    private func attach() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let window, window !== installedWindow else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installedWindow = window
    }

    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

extension View {
    /// Keyboard niceties for forms: scrolling dismisses it, and a Done button sits above it
    /// (number pads have no return key, so otherwise there would be no way to close them).
    func keyboardFriendly() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
    }
}
