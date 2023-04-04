//
//  FluidMenuBarExtraStatusItem.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI

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

        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissWindow()
        }

        window.delegate = self
        localEventMonitor?.start()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func toggleWindow() {
        if window.isVisible {
            dismissWindow()
            return
        }

        setWindowPosition()

        // Tells the system to persist the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        toggleWindow()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        globalEventMonitor?.start()
        setButtonHighlighted(to: true)
    }

    private func dismissWindow() {
        // Tells the system to cancel persisting the menu bar in full screen mode.
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
        globalEventMonitor?.stop()

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
        } else {
            // If there's no screen, assume default positioning.
            targetRect.origin.x -= Metrics.windowBorderSize
        }

        window.setFrameTopLeftPoint(targetRect.origin)
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
