//
//  FluidMenuBarExtraDelegate.swift
//  
//
//  Created by Adam on 20/04/2023.
//

import Foundation

public protocol FluidMenuBarExtraDelegate: AnyObject {
    func menuBarExtraShouldBecomeActive() -> Bool
    func menuBarExtraBecomeActive()
    func menuBarExtraWasDeactivated()
}
