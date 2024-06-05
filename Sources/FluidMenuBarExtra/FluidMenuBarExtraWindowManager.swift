//
//  FluidMenuBarExtraStatusItem.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI

/// An individual element displayed in the system menu bar that displays a window when triggered.
public class FluidMenuBarExtraWindowManager: NSObject, NSWindowDelegate, ObservableObject {
    
    private var mainWindow: ModernMenuBarExtraWindow!
    
   
    
    private var subWindowMonitor: Any?

    
    public var currentSubwindowDelegate: SubwindowDelegate?
    public let statusItem: NSStatusItem

    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    private var mouseMonitor: EventMonitor?

    private var mainWindowVisible = false
    
  

    var sessionID = UUID()
    
    var latestCursorPosition: NSPoint?

    private init(title: String, @ViewBuilder windowContent: @escaping () -> AnyView) {
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.isVisible = true
        
        statusItem.button?.title = title
        statusItem.button?.setAccessibilityTitle(title)
        
        super.init()
        
        let window = ModernMenuBarExtraWindow(title: title, content: windowContent)
        self.mainWindow = window
        
        window.windowManager = self
        
        self.setWindowPosition(window)
        
        setupEventMonitors()
        
        window.delegate = self
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    func setMonospacedFont() {
        if let button = statusItem.button {
            let currentFontSize = button.font?.pointSize ?? NSFont.systemFontSize
            button.font = NSFont.monospacedDigitSystemFont(ofSize: currentFontSize, weight: .regular)
        }
    }
    
    public func windowDidBecomeMain(_ notification: Notification) {}

    func setTitle(newTitle: String?) {
        self.statusItem.button?.title = newTitle ?? ""
        DispatchQueue.main.async {
            self.setWindowPosition(self.mainWindow)
        }
    }
    
    func setImage(imageName: String) {
        statusItem.button?.image = NSImage(named: imageName)
    }
    
    func setImage(systemImageName: String, accessibilityDescription: String? = nil) {
        statusItem.button?.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: accessibilityDescription)
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if mainWindowVisible {
            dismissWindow(mainWindow)
            return
        }
       
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
       
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindowVisible = true
        setWindowPosition(mainWindow)
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == mainWindow {
            globalEventMonitor?.start()
            mouseMonitor?.start()
            setButtonHighlighted(to: true)
        }
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
       
            
            dismissWindow(mainWindow)
            mainWindowVisible = false
            globalEventMonitor?.stop()
        
    }
    
    private func dismissWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        
        if !window.isVisible {
            window.close()
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            
            
            
            window.close()
            window.alphaValue = 1
            if let self = self, !self.mainWindow.isVisible {
                self.setButtonHighlighted(to: false)
                DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
            }
        }
    }

    private func setButtonHighlighted(to highlight: Bool) {
        statusItem.button?.highlight(highlight)
    }

    private func setWindowPosition(_ window: NSWindow) {
        guard let statusItemWindow = statusItem.button?.window else {
            window.center()
            return
        }

        var targetRect = statusItemWindow.frame

        if let screen = statusItemWindow.screen {
            let windowWidth = window.frame.width
            if statusItemWindow.frame.origin.x + windowWidth > screen.visibleFrame.width {
                targetRect.origin.x += statusItemWindow.frame.width
                targetRect.origin.x -= windowWidth
                targetRect.origin.x += Metrics.windowBorderSize
            } else {
                targetRect.origin.x -= Metrics.windowBorderSize
            }
        } else {
            targetRect.origin.x -= Metrics.windowBorderSize
        }
        window.setFrameTopLeftPoint(targetRect.origin)
    }

 
   
    func mouseMoved(event: NSEvent) {
       
        //print("Mouse moved")
            
            let cursorPosition = NSEvent.mouseLocation
            self.latestCursorPosition = cursorPosition
            mainWindow?.mouseMoved(to: cursorPosition)
        
    }
    
    
    public func windowWillClose(_ notification: Notification) {}
}

public extension FluidMenuBarExtraWindowManager {
    convenience init(title: String, @ViewBuilder content: @escaping () -> AnyView) {
        self.init(title: title, windowContent: content)
        statusItem.button?.setAccessibilityTitle(title)
    }

    convenience init(title: String, image: String, @ViewBuilder content: @escaping () -> AnyView) {
        self.init(title: title, windowContent: content)
        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(named: image)
    }

    convenience init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> AnyView) {
        self.init(title: title, windowContent: content)
        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
    }
}

public extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}

public enum Metrics {
    static let windowBorderSize: CGFloat = 2
}

public protocol SubwindowDelegate {
    func mouseExitedSubwindow()
}

extension NSWindow {
    func isMouseInside(mouseLocation: NSPoint, tolerance: CGFloat) -> Bool {
        var windowFrame = self.frame
        windowFrame.size.width += tolerance
        return windowFrame.contains(mouseLocation)
    }
}

public protocol SubWindowSelectionManager {
    func setWindowHovering(_ hovering: Bool, id: String?)
}

// Helper methods to setup event monitors
private extension FluidMenuBarExtraWindowManager {
    func setupEventMonitors() {
        localEventMonitor = LocalEventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if let button = self.statusItem.button, event.window == button.window, !event.modifierFlags.contains(.command) {
                self.didPressStatusBarButton(button)
                return nil
            }
            return event
        }

        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if self.mainWindow.isKeyWindow {
                self.mainWindow.resignKey()
            }
        }

        mouseMonitor = LocalEventMonitor(mask: [.mouseMoved, .mouseEntered, .mouseExited]) { event in
            self.mouseMoved(event: event)
            return event
        }

        localEventMonitor?.start()
        globalEventMonitor?.start()
        mouseMonitor?.start()
    }
}
