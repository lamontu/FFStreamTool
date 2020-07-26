//
//  AppDelegate.swift
//  FFStreamTool
//
//  Created by YuXiaofei on 2020/6/7.
//  Copyright © 2020 YuXiaofei. All rights reserved.
//


import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(videoCRF: 23.0, keepOriginalSize: true, width: 1280, height: 720, audioMode: "压制音频", audioBitRate: "128k", outputFormat: "mp4").frame(minWidth: 720, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }

        return true
    }
}

