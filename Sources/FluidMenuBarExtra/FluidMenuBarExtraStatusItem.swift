import AppKit
import SwiftUI
import Carbon

/// An individual element displayed in the system menu bar that displays a window
/// when triggered.
final class FluidMenuBarExtraStatusItem: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusItem: NSStatusItem

    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?

    private init(window: NSWindow) {
        self.window = window

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        super.init()

        localEventMonitor = LocalEventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            if let button = self?.statusItem.button, event.window == button.window, !event.modifierFlags.contains(.command) {
                self?.didPressStatusBarButton(button)

                // Stop propagating the event so that the button remains highlighted.
                return nil
            }

            return event
        }

        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, window.isKeyWindow {
                // Resign key window status if an external non-activating event is triggered,
                // such as other system status bar menus.
                window.resignKey()
            }
        }

        window.delegate = self
        localEventMonitor?.start()
        registerForMenuBarEvents()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func setTitle(newTitle: String?) {
        self.statusItem.button?.title = newTitle ?? ""
    }

    func setImage(imageName: String) {
        statusItem.button?.image = NSImage(named: imageName)
    }

    func setImage(systemImageName: String, accessibilityDescription: String? = nil) {
        statusItem.button?.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: accessibilityDescription)
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if window.isVisible {
            dismissWindow(animated: true)
            return
        }

        setWindowPosition()

        // Tells the system to persist the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        globalEventMonitor?.start()
        setButtonHighlighted(to: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        globalEventMonitor?.stop()
        dismissWindow(animated: true)
    }

    private func dismissWindow(animated: Bool) {
        // Tells the system to cancel persisting the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                window.animator().alphaValue = 0

            } completionHandler: { [weak self] in
                self?.window.orderOut(nil)
                self?.window.alphaValue = 1
                self?.setButtonHighlighted(to: false)
            }
        } else {
            window.orderOut(nil)
            window.alphaValue = 1
            setButtonHighlighted(to: false)
        }
    }

    private func setButtonHighlighted(to highlight: Bool) {
        statusItem.button?.highlight(highlight)
    }

    private func setWindowPosition() {
        guard let statusItemWindow = statusItem.button?.window else {
            // If we don't know where the status item is, just place the window in the center.
            window.center()
            return
        }

        var targetRect = statusItemWindow.frame

        if let screen = statusItemWindow.screen {
            let windowWidth = window.frame.width

            if statusItemWindow.frame.origin.x + windowWidth > screen.visibleFrame.width {
                targetRect.origin.x += statusItemWindow.frame.width
                targetRect.origin.x -= windowWidth

                // Offset by window border size to align with highlighted button.
                targetRect.origin.x += Metrics.windowBorderSize

            } else {
                // Offset by window border size to align with highlighted button.
                targetRect.origin.x -= Metrics.windowBorderSize
            }
        } else {
            // If there's no screen, assume default positioning.
            targetRect.origin.x -= Metrics.windowBorderSize
        }

        window.setFrameTopLeftPoint(targetRect.origin)
    }

    // Register for menu bar events
    private func registerForMenuBarEvents() {
        let eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: UInt32(kEventClassMenu), eventKind: UInt32(kEventMenuBarHidden)),
            EventTypeSpec(eventClass: UInt32(kEventClassMenu), eventKind: UInt32(kEventMenuBarShown))
        ]

        let eventHandler: EventHandlerProcPtr = { (inHandlerCallRef, inEvent, userData) -> OSStatus in
            guard let inEvent = inEvent else {
                return OSStatus(eventNotHandledErr)
            }

            let eventKind = GetEventKind(inEvent)
            let selfInstance = Unmanaged<FluidMenuBarExtraStatusItem>.fromOpaque(userData!).takeUnretainedValue()

            switch eventKind {
            case UInt32(kEventMenuBarHidden):
                selfInstance.dismissWindow(animated: false)
            case UInt32(kEventMenuBarShown):
                // Handle menu bar shown if needed
                break
            default:
                return OSStatus(eventNotHandledErr)
            }

            return noErr
        }

        var eventHandlerRef: EventHandlerRef?
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), eventHandler, eventTypes.count, eventTypes, userData, &eventHandlerRef)

        if status != noErr {
            print("Failed to register event handler")
        } else {
            print("Event handler registered successfully")
        }

        // Register for Mission Control events
        registerForMissionControlEvents()
    }

    private func registerForMissionControlEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(missionControlDidActivate),
                                                          name: NSNotification.Name("com.apple.notificationcenterui.MissionControlDidActivate"),
                                                          object: nil)
    }

    @objc private func missionControlDidActivate() {
        dismissWindow(animated: false)
    }
}

extension FluidMenuBarExtraStatusItem {
    convenience init(title: String, window: NSWindow) {
        self.init(window: window)

        statusItem.button?.title = title
        statusItem.button?.setAccessibilityTitle(title)
    }

    convenience init(title: String, image: String, window: NSWindow) {
        self.init(window: window)

        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(named: image)
    }

    convenience init(title: String, systemImage: String, window: NSWindow) {
        self.init(window: window)

        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
    }
}

private extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}

private enum Metrics {
    static let windowBorderSize: CGFloat = 2
}
