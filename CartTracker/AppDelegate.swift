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

    var menu: NSMenu!
    var statusMenuEntry: NSMenuItem!

    var aboutWindow: AboutWindow!

    static var shared: AppDelegate!

    // MARK: NSApplicationDelegate protocol

    @objc func applicationDidFinishLaunching(_ notification: Notification) {
        self.aboutWindow = AboutWindow()
        self.statusBar = NSStatusBar.system
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.statusBarButton = self.statusItem.button

        if self.statusBarButton == nil {
            NSLog("Failed to initialize a status bar button")
            return
        }

        self.statusBarButton.title = "CART"

        self.statusMenuEntry = NSMenuItem()
        self.statusMenuEntry.title = "Fetching..."
        self.statusMenuEntry.isEnabled = false

        let aboutMenuItem = NSMenuItem()
        aboutMenuItem.title = "About CartTracker"
        aboutMenuItem.target = self
        aboutMenuItem.action = #selector(showAboutWindow)

        let quitMenuItem = NSMenuItem()
        quitMenuItem.title = "Quit"
        quitMenuItem.keyEquivalent = "q"
        quitMenuItem.target = self
        quitMenuItem.action = #selector(quit)

        self.menu = NSMenu()
        self.menu.addItem(self.statusMenuEntry)
        self.menu.addItem(NSMenuItem.separator())
        self.menu.addItem(aboutMenuItem)
        self.menu.addItem(NSMenuItem.separator())
        self.menu.addItem(quitMenuItem)

        self.statusItem.menu = menu

        let center = NotificationCenter.default
        center.addObserver(forName: .onTickerUpdated, object: nil, queue: OperationQueue.main) { updateObj in
            guard let update = updateObj.object as? TickerUpdate else {
                NSLog("Not a ticker update")
                return
            }

            self.storeLastTick(update)
            self.showTick(update)
        }

        if let tick = self.fetchLastTick() {
            self.showTick(tick)
        }

        self.ticker = Ticker()

        self.listenForSleepAndWake()

        self.ticker.resume()
    }

    private func listenForSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: OperationQueue.main) { _ in
                self.ticker.pause()
            }

        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: OperationQueue.main) { _ in
                self.ticker.resume()
            }
    }

    // MARK: Menu handlers

    @objc func showAboutWindow() {
        aboutWindow.show()
    }

    @objc func quit() {
        NSApplication.shared.terminate(0)
    }

    private func showTick(_ tick: TickerUpdate) {
        self.statusBarButton.title = "\(tick.symbol) \(tick.displayPrice) (\(tick.delta))"
        if let notice = tick.quoteMarketNotice {
            self.statusMenuEntry.title = notice
            self.statusBarButton.toolTip = notice
        }
    }

    private func storeLastTick(_ tick: TickerUpdate) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(tick) {
            UserDefaults.standard.set(data, forKey: "last-tick")
        }
    }

    private func fetchLastTick() -> TickerUpdate? {
        guard let data = UserDefaults.standard.data(forKey: "last-tick") else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(TickerUpdate.self, from: data)
    }
}

