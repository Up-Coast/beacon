// The floating report button: a small round button that sits above the
// host's own windows, so a tester can report from wherever they are
// instead of digging through Settings for a menu item.
//
// It is on unless the host turns it off with `showsFloatingButton: false`,
// and Beacon puts it up itself once reporting is offered. The host adds
// nothing to its views for it. Pressing it opens the report sheet in a
// window of its own; the button hides while the sheet is open, so it never
// lands in the sheet's own screenshot.

import SwiftUI
import BeaconCore
import BeaconUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The round button itself, the same on both platforms.
struct FloatingReportBadge: View {
    static let diameter: CGFloat = 44
    var title: String
    var action: () -> Void

    var body: some View {
        Image(systemName: "exclamationmark.bubble.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Circle().fill(Color.accentColor))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(title))
            .accessibilityAction(.default, action)
            .help(title)
    }
}

@MainActor
final class FloatingReportButton {
    static let shared = FloatingReportButton()
    static let title = "Report a problem"
    static let margin: CGFloat = 24

    private var isReporting = false

    #if os(macOS)
    private var panel: NSPanel?
    private var reportWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show() {
        if panel == nil { panel = makePanel() }
        guard !isReporting else { return }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let size = FloatingReportBadge.diameter
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        // Above this app's windows while it is in use; out of the way of
        // every other app's when it isn't.
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView:
            FloatingReportBadge(title: Self.title) { [weak self] in self?.openReport() }
                .gesture(WindowDragGesture()))
        if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size - Self.margin,
                                         y: visible.minY + Self.margin))
        }
        return panel
    }

    private func openReport() {
        guard Beacon.isConfigured, reportWindow == nil else {
            reportWindow?.makeKeyAndOrderFront(nil)
            return
        }
        isReporting = true
        hide()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 660),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = Self.title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView:
            BeaconSheet(configuration: Beacon.configuration,
                        gitHubAccount: Beacon.gitHubAccount,
                        onClose: { [weak window] in window?.close() }))
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportClosed() }
        }
        reportWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func reportClosed() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        reportWindow = nil
        isReporting = false
        show()
    }
    #else
    private var window: UIWindow?
    private var sceneObserver: NSObjectProtocol?

    func show() {
        if let window {
            window.isHidden = isReporting
            return
        }
        if attach() { return }
        // At launch the app's scene may not be on screen yet.
        guard sceneObserver == nil else { return }
        sceneObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.attach() }
        }
    }

    func hide() {
        window?.isHidden = true
    }

    private func attach() -> Bool {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
            return window != nil
        }
        let overlay = PassThroughWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        let host = UIHostingController(rootView: FloatingOverlay { [weak self] in
            self?.openReport()
        })
        host.view.backgroundColor = .clear
        overlay.rootViewController = host
        overlay.isHidden = isReporting
        window = overlay
        if let sceneObserver { NotificationCenter.default.removeObserver(sceneObserver) }
        sceneObserver = nil
        return true
    }

    private func openReport() {
        guard Beacon.isConfigured, !isReporting,
              let presenter = topViewController() else { return }
        isReporting = true
        hide()
        var sheet: UIViewController?
        let host = UIHostingController(rootView:
            BeaconSheet(configuration: Beacon.configuration,
                        gitHubAccount: Beacon.gitHubAccount,
                        onClose: { [weak self] in
                            sheet?.dismiss(animated: true) { self?.reportClosed() }
                        }))
        sheet = host
        host.presentationController?.delegate = DismissWatcher.shared
        DismissWatcher.shared.onDismiss = { [weak self] in self?.reportClosed() }
        presenter.present(host, animated: true)
    }

    private func reportClosed() {
        isReporting = false
        show()
    }

    /// The app's own top-most screen, never the overlay.
    private func topViewController() -> UIViewController? {
        let scene = window?.windowScene
        let appWindow = scene?.windows.first { $0 !== window && $0.isKeyWindow }
            ?? scene?.windows.first { $0 !== window && !$0.isHidden }
        var top = appWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}

#if os(iOS)
/// A window that lets every touch through except on the button.
private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === rootViewController?.view ? nil : hit
    }
}

/// The button, draggable anywhere on the screen.
private struct FloatingOverlay: View {
    var action: () -> Void
    @State private var position: CGPoint?
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let resting = position ?? CGPoint(
                x: proxy.size.width - FloatingReportBadge.diameter / 2 - FloatingReportButton.margin,
                y: proxy.size.height - FloatingReportBadge.diameter / 2 - FloatingReportButton.margin * 3)
            FloatingReportBadge(title: FloatingReportButton.title, action: action)
                .position(x: resting.x + drag.width, y: resting.y + drag.height)
                .gesture(DragGesture()
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        position = CGPoint(x: resting.x + value.translation.width,
                                           y: resting.y + value.translation.height)
                    })
        }
        .ignoresSafeArea(.keyboard)
    }
}

/// Brings the button back when the reporter swipes the sheet away.
@MainActor
private final class DismissWatcher: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = DismissWatcher()
    var onDismiss: (() -> Void)?

    nonisolated func presentationControllerDidDismiss(_ controller: UIPresentationController) {
        MainActor.assumeIsolated { onDismiss?() }
    }
}
#endif
