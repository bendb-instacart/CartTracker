//
//  main.swift
//  CartTracker
//
//  Created by Ben Bader on 9/25/23.
//

import AppKit
import Foundation

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

AppDelegate.shared = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
