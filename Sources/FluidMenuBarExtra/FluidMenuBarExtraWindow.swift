//
//  FluidMenuBarExtraWindow.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-16.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI

/// A custom window configured to behave as closely to an `NSMenu` as possible.
///
/// `FluidMenuBarExtraWindow` listens for changes to the size of its content and
/// automatically adjusts its frame to match.
class FluidMenuBarExtraWindow<Content: View>: NSPanel, ContentUpdatable {
    
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
    
    private var content: () -> Content

    private lazy var visualEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        view.translatesAutoresizingMaskIntoConstraints = true
        return view
    }()

    private unowned var windowManager: FluidMenuBarExtraWindowManager
     
    private var rootView: AnyView {
        AnyView(
            content()
                .environmentObject(windowManager)
                .modifier(RootViewModifier(windowTitle: title))
                .onSizeUpdate { [weak self] size in
                    self?.latestCGSize = size
                    if (self?.resize ?? true) {
                        self?.contentSizeDidUpdate(to: size)
                    }
                }
        )
    }
     
    func setWindowManager(_ manager: FluidMenuBarExtraWindowManager) {
        self.windowManager = manager
    }

    private var hostingView: NSHostingView<AnyView>!

    init(contentRect: CGRect? = nil, title: String, windowManager: FluidMenuBarExtraWindowManager, content: @escaping () -> Content) {
        self.content = content
        self.windowManager = windowManager
         
        super.init(
            contentRect: contentRect ?? CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = title

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
        self.content = { newContent as! Content }
        
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

protocol ContentUpdatable {
    func updateContent(to newContent: AnyView)
}
