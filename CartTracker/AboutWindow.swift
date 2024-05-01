//
//  AboutWindow.swift
//  CartTracker
//
//  Created by Ben Bader on 9/26/23.
//

import AppKit
import Foundation
import SwiftUI

class AboutWindow {
    private let window: NSWindow

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: false)

        window.title = "CartTracker"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
    }

    func show() {
        if !window.isVisible {
            // If we haven't yet shown the window, center it.  If the window is already open,
            // then it's weird to move it around again, so don't.
            window.center()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct AboutView : View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("RichCarrot")
                .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
            Text("Copyright © Ben Bader")
            Divider()
            HStack {
                Link("Support", destination: URL(string: "https://github.com/bendb-instacart/CartTracker/issues/new")!)
                Link("Privacy Policy", destination: URL(string: "https://github.com/bendb-instacart/CartTracker/blob/main/privacy.md")!)
            }.padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
        }
    }
}
