//
//  MainMenuViewModel.swift
//  How Long Left Mac
//
//  Created by Ryan on 25/5/2024.
//

import Foundation
import SwiftUI


public class WindowSelectionManager: ObservableObject, SubWindowSelectionManager {
    
    @Published public var menuSelection: String? {
        didSet {
            handleSelectionChange(oldValue: oldValue, newValue: menuSelection)
        }
    }
    
    @Published var scrollPosition: CGPoint = .zero
    
    var latestItems = [String]()
    
    private var itemsProvider: MenuSelectableItemsProvider
    
    public var scrollProxy: ScrollViewProxy?
    
    private var latestHoverDate: Date?
    private var latestKeyDate: Date?
    
    private var selectFromHoverWorkItem: DispatchWorkItem?
    private var setHoverWorkItem: DispatchWorkItem?
    
    public weak var submenuManager: ModernMenuBarExtraWindow?
    
    @Published public var clickID: String?
    
    var lastSelectWasByKey = false
    var latestScroll: Date?
    
    public var latestMenuHoverId: String?
    
    public init(itemsProvider: MenuSelectableItemsProvider) {
        self.itemsProvider = itemsProvider
        self.latestItems = itemsProvider.getItems()
    }
    
    public func setWindowHovering(_ hovering: Bool, id: String?) {
        selectFromHoverWorkItem?.cancel()
        setHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            if hovering {
                selectID(id)
            } else if menuSelection == id {
                menuSelection = nil
                selectID(latestMenuHoverId)
            }
        }
        
        setHoverWorkItem = item
        DispatchQueue.main.async(execute: item)
    }
    
    public func setMenuItemHovering(id: String?, hovering: Bool) {
        
        self.latestMenuHoverId = id
        //print("Latest menu hover: \(id)")
        selectID(id)
        
    }
    
    private func selectID(_ idToSelect: String?) {
        guard idToSelect != menuSelection else { return }
        
        selectFromHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            
          
            latestHoverDate = Date()
            if let latestKeyDate = latestKeyDate, Date().timeIntervalSince(latestKeyDate) < 0.5 { return }
            
            lastSelectWasByKey = false
            if menuSelection != idToSelect {
                menuSelection = idToSelect
            }
        }
        
        let delay: TimeInterval = {
            if let latestScroll = latestScroll, Date().timeIntervalSince(latestScroll) < 1 {
                return 1
            } else {
                
                let prev = menuSelection
                return prev == nil ? 0 : 0
            }
        }()
        
        selectFromHoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    func resetHover() {
        latestKeyDate = nil
        
    }
    
    public func clickItem() {
        clickID = menuSelection
    }
    
    public func selectNextItem() {
        guard let currentID = menuSelection else {
            menuSelection = latestItems.first
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex + 1 < ids.count {
            menuSelection = ids[currentIndex + 1]
        }
        
        lastSelectWasByKey = true
        latestKeyDate = Date()
    }
    
   public func selectPreviousItem() {
        guard let currentID = menuSelection else {
            menuSelection = latestItems.last
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex > 0 {
            menuSelection = ids[currentIndex - 1]
        }
        
        lastSelectWasByKey = true
        latestKeyDate = Date()
    }
    
    
    
    private func handleSelectionChange(oldValue: String?, newValue: String?) {
        submenuManager?.closeSubwindow(notify: false) // Do not notify self (Because we already know!)
        
        
        if let newValue = newValue {
            submenuManager?.openSubWindow(id: newValue)
        }
   
        if lastSelectWasByKey {
            scrollProxy?.scrollTo(newValue, anchor: .bottom)
        }
    }
}

public enum OptionsSectionButton: String, CaseIterable {
    case settings, quit
}

public protocol MenuSelectableItemsProvider {
    
    func getItems() -> [String]
    
}

