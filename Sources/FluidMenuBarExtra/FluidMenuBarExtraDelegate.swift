//
//  FluidMenuBarExtraDelegate.swift
//  
//
//  Created by Adam on 20/04/2023.
//

import Foundation

public protocol FluidMenuBarExtraDelegate: AnyObject {
    func menuBarExtraBecomeActive()
    func menuBarExtraWasDeactivated()
}
