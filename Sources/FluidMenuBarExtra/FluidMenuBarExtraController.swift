//
//  FluidMenuBarExtraController.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import SwiftUI

/// A class you use to render a SwiftUI menu bar extra in both SwiftUI and non-SwiftUI
/// applications.
///
/// A fluid menu bar extra is configured by instantiating it once during the lifecycle of your
/// app, most commonly in your application delegate. In SwiftUI apps, use
/// `NSApplicationDelegateAdaptor` to create an application delegate in which
/// a ``FluidMenuBarExtraController`` can be created:
///
/// ```
/// class AppDelegate: NSObject, NSApplicationDelegate {
///     private var menuBarExtraController: FluidMenuBarExtraController<Text>?
///
///     func applicationDidFinishLaunching(_ notification: Notification) {
///         self.menuBarExtraController = FluidMenuBarExtraController(
///             title: "My Menu",
///             systemImage: "cloud.fill"
///         } {
///             Text("My SwiftUI View")
///         }
///     }
/// }
/// ```
///
/// FluidMenuBarExtraController is generic—you must specify the type of view that
/// is being rendered. Avoid defining complex SwiftUI views with many modifiers
/// directly in the closure passed to `FluidMenuBarExtraController`. Instead,
/// wrap all views in a single parent view. If this isn't possible, consider type-erasing
/// the views with `AnyView`
public final class FluidMenuBarExtraController<Content: View>: ObservableObject {
    private let window: MenuBarExtraWindow<Content>
    private let coordinator: MenuBarExtraCoordinator

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        window = MenuBarExtraWindow(title: title, content: content)
        coordinator = MenuBarExtraCoordinator(title: title, window: window)
    }

    public init(title: String, image: String, @ViewBuilder content: @escaping () -> Content) {
        window = MenuBarExtraWindow(title: title, content: content)
        coordinator = MenuBarExtraCoordinator(title: title, image: image, window: window)
    }

    public init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        window = MenuBarExtraWindow(title: title, content: content)
        coordinator = MenuBarExtraCoordinator(title: title, systemImage: systemImage, window: window)
    }
}
