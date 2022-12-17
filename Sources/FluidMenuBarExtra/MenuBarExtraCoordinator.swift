//
//  MenuBarExtraCoordinator.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI

/// Facilitates communication between a status bar item and the window it opens.
final class MenuBarExtraCoordinator: NSObject, ObservableObject, NSWindowDelegate {
    private unowned let window: NSWindow
    private let statusItem: NSStatusItem

    private var eventMonitor: EventMonitor?

    private init(window: NSWindow) {
        self.window = window

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        super.init()

        eventMonitor = EventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            if let button = self?.statusItem.button, event.window == button.window, !event.modifierFlags.contains(.command) {
                self?.didPressStatusBarButton(button)

                // Stop propagating the event so that the button remains highlighted.
                return nil
            }

            return event
        }

        window.delegate = self
        eventMonitor?.start()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if window.isVisible {
            dismissWindow()
            return
        }

        setWindowPosition()

        // Tells the system to persist the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        setButtonHighlighted(to: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismissWindow()
    }

    private func dismissWindow() {
        // Tells the system to cancel persisting the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            window.animator().alphaValue = 0

        } completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.window.alphaValue = 1
            self?.setButtonHighlighted(to: false)
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
        }

        window.setFrameTopLeftPoint(targetRect.origin)
    }
}

extension MenuBarExtraCoordinator {
    public convenience init(title: String, window: NSWindow) {
        self.init(window: window)

        statusItem.button?.title = title
        statusItem.button?.setAccessibilityTitle(title)
    }

    public convenience init(title: String, image: String, window: NSWindow) {
        self.init(window: window)

        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(named: image)
    }

    public convenience init(title: String, systemImage: String, window: NSWindow) {
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
