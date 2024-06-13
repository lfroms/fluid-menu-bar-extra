//
//  MainMenuViewModel.swift
//  How Long Left Mac
//
//  Created by Ryan on 25/5/2024.
//

import Foundation
import SwiftUI


public class WindowSelectionManager: ObservableObject, SubWindowSelectionManager {
    
    @Published public var selectedItemID: String? {
        didSet {
            handleSelectionChange(oldValue: oldValue, newValue: selectedItemID)
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
    
    var latestActualHoverId: String?
    
    public init(itemsProvider: MenuSelectableItemsProvider) {
        self.itemsProvider = itemsProvider
        self.latestItems = itemsProvider.getItems()
    }
    
    public func setWindowHovering(_ hovering: Bool, id: String?) {
        selectFromHoverWorkItem?.cancel()
        setHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            if hovering {
                selectIDFromHover(id)
            } else if selectedItemID == id {
                selectedItemID = nil
                selectIDFromHover(nil)
            }
        }
        
        setHoverWorkItem = item
        DispatchQueue.main.async(execute: item)
    }
    
    public func selectIDFromHover(_ idToSelect: String?) {
        guard idToSelect != selectedItemID else { return }
        
        selectFromHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [self] in
            
            if let mouseTracker = submenuManager?.windowManager?.speedCalculator {
                
                if mouseTracker.containsSpeed(over: 500) {
                    print("Ignoring")
                    return
                }
                
            }
            
            latestHoverDate = Date()
            if let latestKeyDate = latestKeyDate, Date().timeIntervalSince(latestKeyDate) < 0.5 { return }
            
            lastSelectWasByKey = false
            if selectedItemID != idToSelect {
                selectedItemID = idToSelect
            }
        }
        
        let delay: TimeInterval = {
            if let latestScroll = latestScroll, Date().timeIntervalSince(latestScroll) < 1 {
                return 1
            } else {
                
                let prev = selectedItemID
                return prev == nil ? 0 : 0.15
            }
        }()
        
        selectFromHoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    func resetHover() {
        latestKeyDate = nil
        if let latestActualHoverId {
            selectedItemID = latestActualHoverId
        }
    }
    
    public func clickItem() {
        clickID = selectedItemID
    }
    
    public func selectNextItem() {
        guard let currentID = selectedItemID else {
            selectedItemID = latestItems.first
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex + 1 < ids.count {
            selectedItemID = ids[currentIndex + 1]
        }
        
        lastSelectWasByKey = true
        latestKeyDate = Date()
    }
    
   public func selectPreviousItem() {
        guard let currentID = selectedItemID else {
            selectedItemID = latestItems.last
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex > 0 {
            selectedItemID = ids[currentIndex - 1]
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

