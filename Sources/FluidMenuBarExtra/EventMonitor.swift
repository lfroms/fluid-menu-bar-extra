//
//  EventMonitor.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-17.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit

final class EventMonitor {
    typealias Handler = (NSEvent) -> NSEvent?

    private let mask: NSEvent.EventTypeMask
    private let handler: Handler

    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping Handler) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
