//
//  ModernMenuBarExtraWindow.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-16.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI
import Combine

/// A custom window configured to behave as closely to an `NSMenu` as possible.
///
/// `ModernMenuBarExtraWindow` listens for changes to the size of its content and
/// automatically adjusts its frame to match.
public class ModernMenuBarExtraWindow: NSPanel, NSWindowDelegate, ObservableObject {
    
    public var subWindow: ModernMenuBarExtraWindow?
    
    public var currentHoverId: String?
    
    public var hoverManager: SubWindowSelectionManager?
    
    private var mainWindowVisible = false
    
    private var subwindowID = UUID()
    
    private var openSubwindowWorkItem: DispatchWorkItem?
    private var closeSubwindowWorkItem: DispatchWorkItem?
    
    private var subwindowViews = [String:AnyView]()
    private var subwindowPositions = [String:CGPoint]()
    
    private var latestSubwindowPoint: CGPoint?
    private var subwindowHovering = false
    
    var windowManager: FluidMenuBarExtraWindowManager?
    
    
    var resize = true {
        didSet {
            if let latestCGSize = self.latestCGSize, self.resize == true {
                self.contentSizeDidUpdate(to: latestCGSize)
            }
        }
    }
     
    var isSecondary = false {
        didSet {
            self.level = isSecondary ? .popUpMenu : .normal
            self.isFloatingPanel = isSecondary
            self.hidesOnDeactivate = isSecondary
        }
    }
    
    var latestCGSize: CGSize?
    
    private var content: () -> AnyView

    private lazy var visualEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        view.translatesAutoresizingMaskIntoConstraints = true
        return view
    }()

     
    private var rootView: AnyView {
        AnyView(
            content()
                .environmentObject(self)
                .modifier(RootViewModifier(windowTitle: title))
                .onSizeUpdate { [weak self] size in
                    self?.latestCGSize = size
                    if (self?.resize ?? true) {
                        self?.contentSizeDidUpdate(to: size)
                    }
                }
        )
    }
     


    private var hostingView: NSHostingView<AnyView>!

    init(contentRect: CGRect? = nil, title: String, content: @escaping () -> AnyView) {
        self.content = content
        
         
        super.init(
            contentRect: contentRect ?? CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = title
        self.delegate = self
        isMovable = false
        isMovableByWindowBackground = false
        isFloatingPanel = false
        level = .statusBar
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        animationBehavior = .none
        if #available(macOS 13.0, *) {
            collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        } else {
            collectionBehavior = [.stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        }
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = visualEffectView
        
        setupHostingView()

        visualEffectView.addSubview(hostingView)
        setContentSize(hostingView.intrinsicContentSize)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
        ])
    }
    
    private func setupHostingView() {
        hostingView = NSHostingView(rootView: rootView)
        // Disable NSHostingView's default automatic sizing behavior.
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.isVerticalContentSizeConstraintActive = false
        hostingView.isHorizontalContentSizeConstraintActive = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
    }

    public func resizeBasedOnLastSize() {
        if let latestCGSize = self.latestCGSize {
            self.contentSizeDidUpdate(to: latestCGSize)
        }
    }

    public func contentSizeDidUpdate(to size: CGSize) {
        var nextFrame = frame
        let previousContentSize = contentRect(forFrameRect: frame).size

        let deltaX = size.width - previousContentSize.width
        let deltaY = size.height - previousContentSize.height

        nextFrame.origin.y -= deltaY
        nextFrame.size.width += deltaX
        nextFrame.size.height += deltaY

        guard frame != nextFrame else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.setFrame(nextFrame, display: true, animate: false)
        }
    }
    
    // New method to update the content with AnyView
    public func updateContent(to newContent: AnyView) {
        // Remove old hosting view
        hostingView.removeFromSuperview()
        
        // Update the content closure to return the new content
        self.content = { newContent }
        
        // Recreate the hosting view with the new content
        setupHostingView()

        // Add the new hosting view to the visual effect view
        visualEffectView.addSubview(hostingView)
        setContentSize(hostingView.intrinsicContentSize)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
        ])
    }
    
   
}


// MARK: Subwindow Stuff

extension ModernMenuBarExtraWindow {
    
    public func openSubWindow(id: String) {
        //print("HLD: Open subwindow with \(id)")
        
      //  //print("Open subwindow \(id) ")
        
        closeSubwindowWorkItem?.cancel()
        openSubwindowWorkItem?.cancel()
        
       // if mainWindowVisible == false { return }
        
        var possibleItem: DispatchWorkItem?
        let item = DispatchWorkItem { [self] in
           
            guard let view = subwindowViews[id] else { return }
            guard let pos = subwindowPositions[id] else { return }
            
          /*  if mainWindowVisible == false {
                return
            } */
            
            if let possibleItem, possibleItem.isCancelled {
                return
            }
            
            

            self.latestSubwindowPoint = pos
            subWindow?.close()
            subWindow = nil
            
            let w = ModernMenuBarExtraWindow(title: "Window", content: { AnyView(view) })
            w.isSecondary = true
            w.isReleasedWhenClosed = false
            
            w.delegate = self
            
            w.windowManager = self.windowManager
            
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
    
   

    
    public func registerSubwindowView(view: AnyView, for id: String) {
        subwindowViews[id] = view
    }
    
    public func registerSubwindowButtonPosition(point: CGPoint, for id: String) {
        subwindowPositions[id] = point
    }
    


    func updateSubwindowPosition() {
        guard let subWindow = subWindow else { return }
        guard let point = latestSubwindowPoint else { return }
            
        let subWindowFrame = subWindow.frame
        let mainWindowFrame = self.frame
        
        let adjustedPoint = CGPoint(
            x: mainWindowFrame.minX - subWindowFrame.width + 10,
            y: mainWindowFrame.origin.y + mainWindowFrame.height - point.y
        )

        subWindow.setFrameTopLeftPoint(adjustedPoint)
        self.addChildWindow(subWindow, ordered: .above)
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window == subWindow else { return }
        
        if self.frame.width < 1 { return }
        
        updateSubwindowPosition()
    }
    
    override public func close() {
        
        
        closeSubwindow()
        super.close()
        
    }

    public func closeSubwindow() {
        
        
        
        let id = subwindowID
        
        openSubwindowWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            
         
            if id != subwindowID {
                return
            }
            
            if !subwindowHovering {
               
                hoverManager?.setWindowHovering(false, id: currentHoverId)
                //print("Close subwindow")
                subWindow?.orderOut(nil)
                subWindow?.close()
                subWindow = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
    }
    
   
    func mouseMoved(to cursorPosition: NSPoint) {
        
        if let window = self.subWindow {
                        subwindowHovering = window.isMouseInside(mouseLocation: cursorPosition, tolerance: 3)
                        
                        if subwindowHovering {
                            //print("SWH 3")
                            hoverManager!.setWindowHovering(true, id: currentHoverId)
                            closeSubwindowWorkItem?.cancel()
                        } else {
                            if !self.isMouseInside(mouseLocation: cursorPosition, tolerance: 30) {
                                
                                closeSubwindow()
                            }
                        }
                    }
        
        subWindow?.mouseMoved(to: cursorPosition)
    }
    
}



