<h1 align="center">
  &#128421;
  <br>
  FluidMenuBarExtra 
  <br>
</h1>

<h4 align="center">A lightweight tool for building great menu bar extras with SwiftUI.</h4>

<p align="center">
  <a href="https://github.com/lfroms/fluid-menu-bar-extra/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/lfroms/fluid-menu-bar-extra"></a>
  <img alt="GitHub contributors" src="https://img.shields.io/github/contributors/lfroms/fluid-menu-bar-extra">
  <a href="https://github.com/lfroms/fluid-menu-bar-extra/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/lfroms/fluid-menu-bar-extra"></a>
  <a href="https://github.com/lfroms/fluid-menu-bar-extra"><img alt="GitHub license" src="https://img.shields.io/github/license/lfroms/mobile-device-kit"></a>
  <img alt="Contributions welcome" src="https://img.shields.io/badge/contributions-welcome-orange">
</p>

## About

SwiftUI's built in [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) API makes it easy to create menu bar applications in pure SwiftUI. However, the current implementation of the [`WindowMenuBarExtraStyle`](https://developer.apple.com/documentation/swiftui/windowmenubarextrastyle) is limited in that it doesn't fade out when dismissed like traditional menu items, doesn't persist selection state when the menu is opened, and uses a less-than-ideal resizing mechanism that leaves your app feeling unpolished.

FluidMenuBarExtra is a lightweight package that provides a convenient API for creating seamless menu bar extras with SwiftUI in both AppKit and SwiftUI apps. Once MenuBarExtra is improved in future versions of macOS, switching back to MenuBarExtra is as simple as moving a few lines of SwiftUI code back to your `App`.

### Key Features

- Animated resizing when SwiftUI content changes.
- Ability to access the scene phase of the menu using the `scenePhase` environment key.
- Persisted highlighting of the menu bar button.
- Smooth fade out animation when the menu is dismissed.
- Automatic repositioning if the menu would otherwise surpass the screen edge.

## Usage

To use FluidMenuBarExtra, initialize a `FluidMenuBarExtraController` once during your app's lifecycle. You can instantiate more than one controller if you need more than one menu bar extra.

First, define an application delegate. Don't worry, your app's entry point will still be based in SwiftUI.

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarExtraController: FluidMenuBarExtraController<Text>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.menuBarExtraController = FluidMenuBarExtraController(title: "My Menu", systemImage: "cloud.fill"} {
            Text("My SwiftUI View")
        }
    }
}
```

Then, use the `@NSApplicationDelegateAdaptor` property wrapper to attach the delegate to your SwiftUI application:

```swift
import SwiftUI

@main
struct MyApplication: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsTabs()
        }
    }
}
```

That's it! The menu bar extra will be installed as long as the reference to the `FluidMenuBarExtraController` exists. When the reference is deleted or set to `nil`, the item will be removed from the menu bar.

> **Note** If any stateful properties or utilities need to be shared between your menu bar extra and other windows, you can move those properties to your `AppDelegate`. To allow SwiftUI views to consume published properties, conform the delegate class to `ObservableObject`. SwiftUI will then automatically insert the delegate into the environment. [Learn more](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor).

## Caveats

- It isn't easy to mimic the appearance of an NSMenu perfectly. As a result, you'll find that the window presented by FluidMenuBarExtra has a slighter wider corner radius, but this isn't very noticeable at first glance.

## Contributions

All contributions are welcome. If you have a need for this kind of package, feel free to resolve any issues and add any features that may be useful.

## License

FluidMenuBarExtra is released under the [GPL-3.0 License](LICENSE) unless otherwise noted.
