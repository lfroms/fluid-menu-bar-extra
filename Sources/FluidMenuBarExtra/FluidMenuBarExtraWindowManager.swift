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
    
  
    public let speedCalculator = MouseSpeedCalculator()

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
        if mainWindowVisible || mainWindow.isVisible {
            dismissWindows()
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
       // guard let window = notification.object as? NSWindow else { return }
       
       // print("Resign key")
        
        DispatchQueue.main.async { [self] in
            
            if !mainWindow.isWindowOrSubwindowKey() {
               // print("Found key window")
                dismissWindows()
                mainWindowVisible = false
                globalEventMonitor?.stop()
            }
            
            
        }
           
           
        
    }
    
    private func dismissWindow(window: NSWindow) {
        
        
        if !window.isVisible { window.close() }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            window.close()
            window.alphaValue = 1
            
            if window == self?.mainWindow {
                
                DispatchQueue.main.async {
                    DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
                    self?.setButtonHighlighted(to: false)
                    
                }
            }
            
        }
        
    }
    
    private func dismissWindows() {
     
        let all = mainWindow.getSelfAndSubwindows()
        
        for window in all {
            dismissWindow(window: window)
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

 
    func updateSubwindowPosition(window: ModernMenuBarExtraWindow) {
        
       
        guard let parent = window.parent as? ModernMenuBarExtraWindow  else { return }
        guard let point = parent.latestSubwindowPoint else { return }
        
        let subWindowFrame = window.frame
        let mainWindowFrame = parent.frame
        
        let adjustedPoint = CGPoint(
            x: mainWindowFrame.minX - subWindowFrame.width + 10,
            y: mainWindowFrame.origin.y + mainWindowFrame.height - point.y
        )

        window.setFrameTopLeftPoint(adjustedPoint)
        parent.addChildWindow(window, ordered: .above)
    }
    
    public func windowDidResize(_ notification: Notification) {
        //print("Window did resize")
        guard let window = notification.object as? ModernMenuBarExtraWindow else { return }
        guard window.isSubwindow else { return }
        //print("Window did Resized window was subwindow")
        
        if window.frame.width < 1 { return }
        
        updateSubwindowPosition(window: window)
    }
    
    let queue = DispatchQueue(label: "MouseMovedQueue")
   
    func mouseMoved(event: NSEvent) {
       
        //print("Mouse moved")
        
        let cursorPosition = NSEvent.mouseLocation
            
       
        
       // speedCalculator.updateSpeed(with: event)
            
            
        queue.sync {
            
            self.latestCursorPosition = cursorPosition
            self.mainWindow?.mouseMoved(to: cursorPosition)
            
        }
            
        
        
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
        let result = windowFrame.contains(mouseLocation)
        
        return result
    }
}

public protocol SubWindowSelectionManager {
    func setWindowHovering(_ hovering: Bool, id: String?)
    
    var latestMenuHoverId: String? { get set }
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
