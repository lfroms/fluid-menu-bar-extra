//
//  File.swift
//  
//
//  Created by Ryan on 14/6/2024.
//

import Foundation
import AppKit

import Cocoa

public class MouseSpeedCalculator {
    private var lastMouseLocation: CGPoint?
    private var lastTime: TimeInterval?
    var latestMouseSpeed: Double = 0.0
    private var speedCache: [(timestamp: TimeInterval, speed: Double)] = []

    func updateSpeed(with event: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        let currentTime = event.timestamp

        if let lastLocation = lastMouseLocation, let lastTime = lastTime {
            let distance = hypot(currentLocation.x - lastLocation.x, currentLocation.y - lastLocation.y)
            let timeElapsed = currentTime - lastTime
            
            // Calculate speed as distance over time
            let speed = timeElapsed > 0 ? distance / timeElapsed : 0
            
            if speed == 0 {
                return
            }
            
            latestMouseSpeed = speed
            
            // Add the new speed to the cache
            speedCache.append((timestamp: currentTime, speed: speed))
            
            // Remove speeds older than 1 second from the cache
            speedCache = speedCache.filter { currentTime - $0.timestamp <= 0.5 }
            
            //print("Latest mouse speed: \(latestMouseSpeed)")
            //print("Speed cache: \(speedCache)")
        }
        
        // Update last location and time
        lastMouseLocation = currentLocation
        lastTime = currentTime
    }
    
    public func containsSpeed(over threshold: Double) -> Bool {
            let currentTime = Date().timeIntervalSince1970
        return speedCache.contains { (currentTime - $0.timestamp <= 0.5) && ($0.speed > threshold) }
        }
}
