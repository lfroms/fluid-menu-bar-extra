//
//  Copyright © 2023 Hidden Spectrum, LLC. All rights reserved.
//

import SwiftUI


public class FluidMenuBarExtraController: ObservableObject {
    
    // MARK: Public
    
    public var isWindowVisible: Bool { statusItem?.isWindowVisible ?? false }
    
    // MARK: Internal
    
    weak var statusItem: FluidMenuBarExtraStatusItem?
    
    // MARK: Visibility
    
    public func showWindow() {
        statusItem?.showWindow()
    }
    
    public func dismissWindow(animate: Bool = true, completionHandler: (() -> Void)? = nil) {
        guard let statusItem else {
            completionHandler?()
            return
        }
        statusItem.dismissWindow(animate: animate, completionHandler: completionHandler)
    }
    
    @MainActor
    public func dismissWindow(animate: Bool = true) async {
        await withCheckedContinuation { continuation in
            dismissWindow(animate: animate) {
                continuation.resume()
            }
        }
    }
}
