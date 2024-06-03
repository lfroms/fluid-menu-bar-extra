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
    
    private var mainWindow: NSWindow!
    private var subWindow: NSWindow?
    
    private var currentHoverId: String?
    
    public var hoverManager: SubWindowSelectionManager?
    
    private var subWindowMonitor: Any?
    private var mainWindowVisible = false
    
    public var currentSubwindowDelegate: SubwindowDelegate?
    public let statusItem: NSStatusItem

    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    private var mouseMonitor: EventMonitor?

    private var openSubwindowWorkItem: DispatchWorkItem?
    private var closeSubwindowWorkItem: DispatchWorkItem?
    
    private var latestSubwindowPoint: CGPoint?
    
    private var subwindowHovering = false

    var sessionID = UUID()
    
    private var subwindowViews = [String:AnyView]()
    private var subwindowPositions = [String:CGPoint]()

    private init(title: String, @ViewBuilder windowContent: @escaping () -> AnyView) {
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.isVisible = true
        
        statusItem.button?.title = title
        statusItem.button?.setAccessibilityTitle(title)
        
        super.init()
        
        let window = FluidMenuBarExtraWindow(title: title, windowManager: self, content: windowContent)
        self.mainWindow = window
        
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
            dismissWindow(subWindow)
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
        if window == mainWindow {
            if let subWindow = self.subWindow, subWindow.isVisible {
                dismissWindow(subWindow)
                closeSubwindow()
            }
            dismissWindow(mainWindow)
            mainWindowVisible = false
            globalEventMonitor?.stop()
        } else if window == subWindow {
            dismissWindow(subWindow)
            closeSubwindow()
        }
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
            
            if window == self?.subWindow {
                //print("SWH 1")
                self?.hoverManager?.setWindowHovering(false, id: self?.currentHoverId)
            }
            
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

    private var subwindowID = UUID()

    
    public func registerSubwindowView(view: AnyView, for id: String) {
        subwindowViews[id] = view
    }
    
    public func registerSubwindowButtonPosition(point: CGPoint, for id: String) {
        subwindowPositions[id] = point
    }
    
    public func openSubWindow(id: String) {
        //print("HLD: Open subwindow with \(id)")
        
      //  //print("Open subwindow \(id) ")
        
        closeSubwindowWorkItem?.cancel()
        openSubwindowWorkItem?.cancel()
        
        if mainWindowVisible == false { return }
        
        var possibleItem: DispatchWorkItem?
        let item = DispatchWorkItem { [self] in
           
            guard let view = subwindowViews[id] else { return }
            guard let pos = subwindowPositions[id] else { return }
            
            if mainWindowVisible == false {
                return
            }
            
            if let possibleItem, possibleItem.isCancelled {
                return
            }

            self.latestSubwindowPoint = pos
            subWindow?.close()
            subWindow = nil
            
            let w = FluidMenuBarExtraWindow(title: "Window", windowManager: self, content: { AnyView(view) })
            w.delegate = self
            w.isSecondary = true
            w.isReleasedWhenClosed = false
            
            if !(possibleItem?.isCancelled ?? false) {
                subWindow = w
                
                self.currentHoverId = id
                self.subwindowID = UUID()
                //print("SWH 2 \(id)")
                hoverManager?.setWindowHovering(true, id: id)
                subWindow?.orderFrontRegardless()
            }
        }
        
        possibleItem = item
        self.openSubwindowWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }
    
    func mouseMoved(event: NSEvent) {
        DispatchQueue.main.async { [self] in
          
            
            let cursorPosition = NSEvent.mouseLocation
            
            if let window = self.subWindow {
                subwindowHovering = window.isMouseInside(mouseLocation: cursorPosition, tolerance: 3)
                
                if subwindowHovering {
                    //print("SWH 3")
                    hoverManager!.setWindowHovering(true, id: currentHoverId)
                    closeSubwindowWorkItem?.cancel()
                } else {
                    if !mainWindow.isMouseInside(mouseLocation: cursorPosition, tolerance: 30) {
                        
                        closeSubwindow()
                    }
                }
            }
        }
    }

    func updateSubwindowPosition() {
        guard let subWindow = subWindow else { return }
        guard let point = latestSubwindowPoint else { return }
            
        let subWindowFrame = subWindow.frame
        let mainWindowFrame = mainWindow.frame
        
        let adjustedPoint = CGPoint(
            x: mainWindowFrame.minX - subWindowFrame.width + 10,
            y: mainWindowFrame.origin.y + mainWindowFrame.height - point.y
        )

        subWindow.setFrameTopLeftPoint(adjustedPoint)
        mainWindow.addChildWindow(subWindow, ordered: .above)
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window == subWindow else { return }
        
        if mainWindow.frame.width < 1 { return }
        
        updateSubwindowPosition()
    }

    public func closeSubwindow(force: Bool = false, notify: Bool = true) {
        let id = subwindowID
        
        openSubwindowWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            if id != subwindowID {
                return
            }
            
            if !subwindowHovering || force {
                //print("SWH 4")
                if notify {
                    hoverManager?.setWindowHovering(false, id: currentHoverId)
                }
               
                
                subWindow?.orderOut(nil)
                subWindow?.close()
                subWindow = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: item)
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
