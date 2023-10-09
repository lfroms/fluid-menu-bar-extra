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
    
    public func dismissWindow() {
        statusItem?.dismissWindow()
    }
}
