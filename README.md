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

<p align="center">
  <img alt="Menu Sample" src="https://user-images.githubusercontent.com/3951690/208313040-34f97eb5-1ac2-4f25-a510-ba30da2303e8.gif" width="300px">
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

To use FluidMenuBarExtra, initialize a `FluidMenuBarExtra` once during your app's lifecycle. Multiple instances of `FluidMenuBarExtra` can exist if you need more than one menu bar extra.

First, define an application delegate. Don't worry, your app's entry point will still be based in SwiftUI.

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarExtra: FluidMenuBarExtra?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.menuBarExtra = FluidMenuBarExtra(title: "My Menu", systemImage: "cloud.fill"} {
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

That's it! The menu bar extra will be installed as long as the reference to the `FluidMenuBarExtra` exists. When the reference is deleted or set to `nil`, the item will be removed from the menu bar.

> 💡 **Tip:** If any stateful properties or utilities need to be shared between your menu bar extra and other windows, you can move those properties to your `AppDelegate`. To allow SwiftUI views to consume published properties, conform the delegate class to `ObservableObject`. SwiftUI will then automatically insert the delegate into the environment. [Learn more](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor).

## Caveats

- SwiftUI applications require at least one `Scene` be valid. Because FluidMenuBarExtra is not created in a scene, you'll need at least one other scene in the body of your `App`:
   - A common trick is to use a `Settings` scene with an `EmptyView()` inside.
   - Alternatively, you can try using the undocumented yet still public `_EmptyScene()`, but no guarantees that App Review will like it.
- Since FluidMenuBarExtra uses an `NSWindow`, not an `NSMenu`, you'll find that the window presented by FluidMenuBarExtra has a slighter wider corner radius than other menus.

## Contributions

All contributions are welcome. If you have a need for this kind of package, feel free to resolve any issues and add any features that may be useful.

## License

FluidMenuBarExtra is released under the [MIT License](LICENSE) unless otherwise noted.
