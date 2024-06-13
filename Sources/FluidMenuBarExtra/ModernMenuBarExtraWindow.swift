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
    
    public weak var subWindow: ModernMenuBarExtraWindow?
    
    public var currentHoverId: String?
    
    public var hoverManager: SubWindowSelectionManager?
    
    private var mainWindowVisible = false
    
    private var subwindowID = UUID()
    
    private var openSubwindowWorkItem: DispatchWorkItem?
    private var closeSubwindowWorkItem: DispatchWorkItem?
    
    private var subwindowViews = [String:AnyView]()
    private var subwindowPositions = [String:CGPoint]()
    
    public var latestSubwindowPoint: CGPoint?
    private var subwindowHovering = false
    
    public let isSubwindow: Bool
    
    @Published var mouseHovering = false
    
    public var windowManager: FluidMenuBarExtraWindowManager?
    
    
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
           // self.isFloatingPanel = isSecondary
            //self.hidesOnDeactivate = isSecondary
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

    init(contentRect: CGRect? = nil, title: String, isSubWindow isSub: Bool = false, content: @escaping () -> AnyView) {
        self.content = content
        self.isSubwindow = isSub
         
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
            
            let w = ModernMenuBarExtraWindow(title: "Window", isSubWindow: true, content: { AnyView(view) })
          //  w.isSecondary = true
            w.isReleasedWhenClosed = true
            
            w.delegate = self.delegate
            
           // w.delegate = self
            
            w.windowManager = self.windowManager
            
            if !(possibleItem?.isCancelled ?? false) {
                subWindow = w
                
                self.currentHoverId = id
                self.subwindowID = UUID()
                //print("SWH 2 \(id)")
                self.addChildWindow(w, ordered: .above)
                hoverManager?.setWindowHovering(true, id: id)
                subWindow?.orderFrontRegardless()
                //subWindow?.makeKeyAndOrderFront(nil)
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

   
    
    override public func close() {
        
        
        closeSubwindow()
        super.close()
        
    }
    
 

    public func closeSubwindow(notify: Bool = true) {
        
        
        
        let id = subwindowID
        
        openSubwindowWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            
         
            if id != subwindowID {
                return
            }
            
            if !subwindowHovering {
               
                if notify {
                    
                    hoverManager?.setWindowHovering(false, id: currentHoverId)
                }
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
                subwindowHovering = window.isCursorInSelfOrSubwindows(cursorPosition: cursorPosition)
                        
                        if subwindowHovering {
                           // print("SWH 3")
                            hoverManager!.setWindowHovering(true, id: currentHoverId)
                            closeSubwindowWorkItem?.cancel()
                        } else {
                           /* if !self.isMouseInside(mouseLocation: cursorPosition, tolerance: 30) {
                                
                                closeSubwindow()
                            }*/
                        }
                    }
        
        subWindow?.mouseMoved(to: cursorPosition)
    }
    
    func isWindowOrSubwindowKey() -> Bool {
        
        if let subWindow {
            if subWindow.isWindowOrSubwindowKey() {
                return true
            }
        }
        
        return self.isKeyWindow && self.isVisible
        
    }
    
    func isCursorInSelfOrSubwindows(cursorPosition: NSPoint) -> Bool {
        
        
        
        if let subWindow {
            if subWindow.isCursorInSelfOrSubwindows(cursorPosition: cursorPosition) {
                return true
            }
        }
        
      
        
        let result = self.isMouseInside(mouseLocation: cursorPosition, tolerance: 0)
        
        if result {
            if self.isKeyWindow == false {
                self.makeKey()
                self.makeFirstResponder(self)
                //print("Changed fr")
            }
            
        }
        
        return result
        
    }
    
    func getAllWindows() -> [ModernMenuBarExtraWindow] {
            var result: [ModernMenuBarExtraWindow] = [self]
            if let subwindow = self.subWindow {
                result.append(contentsOf: subwindow.getAllWindows())
            }
            return result
    }
    
}



