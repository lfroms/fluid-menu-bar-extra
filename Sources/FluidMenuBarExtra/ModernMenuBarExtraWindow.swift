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
/// `ModernMenuBarExtraWindow` listens for changes to the size of its content and
/// automatically adjusts its frame to match.
public class ModernMenuBarExtraWindow: NSPanel, NSWindowDelegate, ObservableObject {
    
    // MARK: - Properties
    
    public weak var subWindow: ModernMenuBarExtraWindow?
    public var currentHoverId: String?
    public var hoverManager: SubWindowSelectionManager?
    
    private var mainWindowVisible = false
    private var subwindowID = UUID()
    private var openSubwindowWorkItem: DispatchWorkItem?
    private var closeSubwindowWorkItem: DispatchWorkItem?
    
    private var subwindowViews = [String: AnyView]()
    private var subwindowPositions = [String: CGPoint]()
    
    public var latestSubwindowPoint: CGPoint?
    private var subwindowHovering = false
    
    public let isSubwindow: Bool
    @Published var mouseHovering = false
    
    public var windowManager: FluidMenuBarExtraWindowManager?
    
    var resize = true {
        didSet {
            if let latestCGSize = self.latestCGSize, self.resize {
                self.contentSizeDidUpdate(to: latestCGSize)
            }
        }
    }
    
    var isSecondary = false {
        didSet {
            self.level = isSecondary ? .popUpMenu : .normal
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
                    if self?.resize ?? true {
                        self?.contentSizeDidUpdate(to: size)
                    }
                }
        )
    }
    
    private var hostingView: NSHostingView<AnyView>!
    
    // MARK: - Initializer
    
    public init(contentRect: CGRect? = nil, title: String, isSubWindow isSub: Bool = false, content: @escaping () -> AnyView) {
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
        configureWindow()
        setupHostingView()
        visualEffectView.addSubview(hostingView)
        setContentSize(hostingView.intrinsicContentSize)
        setupConstraints()
    }
    
    // MARK: - Setup Methods
    
    private func configureWindow() {
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
    }
    
    private func setupHostingView() {
        hostingView = NSHostingView(rootView: rootView)
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.isVerticalContentSizeConstraintActive = false
        hostingView.isHorizontalContentSizeConstraintActive = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
        ])
    }
    
    // MARK: - Content Update Methods
    
    public func updateContent(to newContent: AnyView) {
        hostingView.removeFromSuperview()
        self.content = { newContent }
        setupHostingView()
        visualEffectView.addSubview(hostingView)
        setContentSize(hostingView.intrinsicContentSize)
        setupConstraints()
    }
    
    // MARK: - Size Management
    
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
    
    // MARK: - Subwindow Management
    
    public func openSubWindow(id: String) {
        closeSubwindowWorkItem?.cancel()
        openSubwindowWorkItem?.cancel()
        
        var possibleItem: DispatchWorkItem?
        let item = DispatchWorkItem { [self] in
            guard let view = subwindowViews[id], let pos = subwindowPositions[id] else { return }
            if let possibleItem, possibleItem.isCancelled { return }
            
            self.latestSubwindowPoint = pos
            subWindow?.close()
            subWindow = nil
            
            let subWindow = ModernMenuBarExtraWindow(title: "Window", isSubWindow: true, content: { AnyView(view) })
            subWindow.isReleasedWhenClosed = true
            subWindow.delegate = self.delegate
            subWindow.windowManager = self.windowManager
            
            if !(possibleItem?.isCancelled ?? false) {
                self.subWindow = subWindow
                self.currentHoverId = id
                self.subwindowID = UUID()
                self.addChildWindow(subWindow, ordered: .above)
                subWindow.orderFrontRegardless()
            }
        }
        
        possibleItem = item
        self.openSubwindowWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
    }
    
    public func registerSubwindowView(view: AnyView, for id: String) {
        subwindowViews[id] = view
    }
    
    public func registerSubwindowButtonPosition(point: CGPoint, for id: String) {
        subwindowPositions[id] = point
        
        if id == currentHoverId {
            self.closeSubwindow()
        }
        
        
        
    }
    
    override public func close() {
        closeSubwindow()
        super.close()
    }
    
    public func closeSubwindow(notify: Bool = true) {
        let id = subwindowID
        openSubwindowWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            if id != subwindowID { return }
            if !subwindowHovering {
                if notify {
                    hoverManager?.setWindowHovering(false, id: currentHoverId)
                }
                subWindow?.orderOut(nil)
                subWindow?.close()
                subWindow = nil
            }
        }
        
        closeSubwindowWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
    
    // MARK: - Mouse Handling
    
    func mouseMoved(to cursorPosition: NSPoint) {
        
        let cursorInSelf = self.isMouseInside(mouseLocation: cursorPosition, tolerance: 2)
        
        if cursorInSelf {
            activateWindow()
            
        }
        
        if let window = self.subWindow {
            subwindowHovering = window.isCursorInSelfOrSubwindows(cursorPosition: cursorPosition)
            if subwindowHovering {
                setForceHover(true)
                closeSubwindowWorkItem?.cancel()
            }
        }
        subWindow?.mouseMoved(to: cursorPosition)
    }
    
    func setForceHover(_ force: Bool) {
        hoverManager?.setWindowHovering(force, id: currentHoverId)
    }
    
    func isWindowOrSubwindowKey() -> Bool {
        if let subWindow, subWindow.isWindowOrSubwindowKey() {
            return true
        }
        return self.isKeyWindow && self.isVisible
    }
    
    func isCursorInSelfOrSubwindows(cursorPosition: NSPoint) -> Bool {
        if isMouseInside(mouseLocation: cursorPosition, tolerance: 0) {
            activateWindow()
            return true
        }
        if let subWindow, subWindow.isCursorInSelfOrSubwindows(cursorPosition: cursorPosition) {
            return true
        }
        return false
    }
    
    func getSelfAndSubwindows() -> [ModernMenuBarExtraWindow] {
        var result = [self]
        
        var current: ModernMenuBarExtraWindow? = self
        
        while let nextWindow = current, let subwindow = nextWindow.subWindow {
            result.append(subwindow)
            current = subwindow
        }
        
        return result
    }
    
    func activateWindow() {
        
        if !self.isKeyWindow {
            self.makeKey()
            self.makeFirstResponder(self)
            self.setForceHover(false)
        }
        
    }
    
}
