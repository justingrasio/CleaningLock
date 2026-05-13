//
//  CleaningLockApp.swift
//  CleaningLock
//
//  Created by Jeremia Justin Grasio on 13/05/26.
//

import SwiftUI

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        InputLockService.shared.stopLock()
    }
}
#endif

@main
struct CleaningLockApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
