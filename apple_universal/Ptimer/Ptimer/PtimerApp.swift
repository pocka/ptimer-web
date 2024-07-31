// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

@main
struct PtimerApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
		return true
	}
}
