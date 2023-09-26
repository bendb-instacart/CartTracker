//
//  AppDelegate.swift
//  CartTracker
//
//  Created by Ben Bader on 9/25/23.
//

import AppKit
import Foundation

class AppDelegate : NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusItem: NSStatusItem!
    var statusBarButton: NSStatusBarButton!
    var ticker: Ticker!

    static var shared: AppDelegate!

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.statusBar = NSStatusBar.system
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.statusBarButton = self.statusItem.button

        if self.statusBarButton == nil {
            NSLog("Failed to initialize a status bar button")
            return
        }

        self.statusBarButton.title = "$CART"

        let quitMenuItem = NSMenuItem()
        quitMenuItem.title = "Quit"
        quitMenuItem.keyEquivalent = "q"
        quitMenuItem.target = self
        quitMenuItem.action = #selector(quit)

        let menu = NSMenu()
        menu.addItem(quitMenuItem)

        self.statusItem.menu = menu

        let center = NotificationCenter.default
        center.addObserver(forName: .onTickerUpdated, object: nil, queue: OperationQueue.main) { updateObj in
            guard let update = updateObj.object as? TickerUpdate else {
                NSLog("Not a ticker update")
                return
            }

            NSLog("Received update: \(update)")

            self.statusBarButton.title = "\(update.symbol) $\(update.price) (\(update.delta))"
        }

        self.ticker = Ticker()
    }

    @objc func quit() {
        NSApplication.shared.terminate(0)
    }
}

