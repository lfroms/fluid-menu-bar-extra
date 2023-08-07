//
//  FluidMenuBarExtra.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import SwiftUI

/// A class you use to create a SwiftUI menu bar extra in both SwiftUI and non-SwiftUI
/// applications.
///
/// A fluid menu bar extra is configured by initializing it once during the lifecycle of your
/// app, most commonly in your application delegate. In SwiftUI apps, use
/// `NSApplicationDelegateAdaptor` to create an application delegate in which
/// a ``FluidMenuBarExtra`` can be created:
///
/// ```swift
/// class AppDelegate: NSObject, NSApplicationDelegate {
///     private var menuBarExtra: FluidMenuBarExtra?
///
///     func applicationDidFinishLaunching(_ notification: Notification) {
///         menuBarExtra = FluidMenuBarExtra(title: "My Menu", systemImage: "cloud.fill") {
///             Text("My SwiftUI View")
///         }
///     }
/// }
/// ```
///
/// Because an application delegate is a plain object, not a `View` or `Scene`, you
/// can't pass state properties to views in the closure of `FluidMenuBarExtra` directly.
/// Instead, define state properties inside child views, or pass published properties from
/// your application delegate to the child views using the `environmentObject`
/// modifier.
public final class FluidMenuBarExtra {
    public let statusItem: FluidMenuBarExtraStatusItem

    public var image: NSImage? {
        get { statusItem.statusItem.button?.image }
        set { statusItem.statusItem.button?.image = newValue }
    }
    
    public init(
        title: String,
        menuBarExtraDelegate: FluidMenuBarExtraDelegate? = nil,
        cornerRadius: CGFloat = 7,
        maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
        @ViewBuilder content: @escaping () -> some View
    ) {
        let window = FluidMenuBarExtraWindow(title: title, cornerRadius: cornerRadius, maskedCorners: maskedCorners, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, window: window)
        statusItem.menuBarExtraDelegate = menuBarExtraDelegate
    }

    public init(
        title: String,
        image: String,
        menuBarExtraDelegate: FluidMenuBarExtraDelegate? = nil,
        cornerRadius: CGFloat = 7,
        maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
        @ViewBuilder content: @escaping () -> some View
    ) {
        let window = FluidMenuBarExtraWindow(title: title, cornerRadius: cornerRadius, maskedCorners: maskedCorners, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, image: image, window: window)
        statusItem.menuBarExtraDelegate = menuBarExtraDelegate
    }

    public init(
        title: String,
        systemImage: String,
        menuBarExtraDelegate: FluidMenuBarExtraDelegate? = nil,
        cornerRadius: CGFloat = 7,
        maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
        @ViewBuilder content: @escaping () -> some View
    ) {
        let window = FluidMenuBarExtraWindow(title: title, cornerRadius: cornerRadius, maskedCorners: maskedCorners, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, systemImage: systemImage, window: window)
        statusItem.menuBarExtraDelegate = menuBarExtraDelegate
    }
    
    public init(
        title: String,
        nsImage: NSImage,
        menuBarExtraDelegate: FluidMenuBarExtraDelegate? = nil,
        cornerRadius: CGFloat = 7,
        maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
        @ViewBuilder content: @escaping () -> some View
    ) {
        let window = FluidMenuBarExtraWindow(title: title, cornerRadius: cornerRadius, maskedCorners: maskedCorners, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, nsImage: nsImage, window: window)
        statusItem.menuBarExtraDelegate = menuBarExtraDelegate
    }
    
    public func showWindow() {
        statusItem.showWindow()
    }
    
    public func closeWindow() {
        statusItem.dismissWindow()
    }

    public func toggleMenuBarExtra() {
        statusItem.toggleWindow()
    }
}
