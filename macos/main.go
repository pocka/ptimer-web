// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"github.com/progrium/darwinkit/macos"
	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/objc"

	"github.com/pocka/ptimer/ptimer"
	"github.com/pocka/ptimer/scene"
	"github.com/pocka/ptimer/scene/picker"
	"github.com/pocka/ptimer/scene/player"

	_ "modernc.org/sqlite"
)

func main() {
	macos.RunApp(func(app appkit.Application, delegate *appkit.ApplicationDelegate) {
		app.SetActivationPolicy(appkit.ApplicationActivationPolicyRegular)

		var scene scene.Scene

		scene = picker.New(func(ptimer *ptimer.Ptimer) {
			scene.Terminate()
			scene = player.New(ptimer)
		})

		menu := appkit.NewMenu()
		app.SetMainMenu(menu)

		appMenuItem := appkit.NewMenuItemWithSelector("", "", objc.Selector{})
		appMenu := appkit.NewMenuWithTitle("App")

		appMenu.AddItem(appkit.NewMenuItemWithAction("Open file", "o", func(objc.Object) {
			ptimer, err := picker.Show()
			if err != nil {
				picker.DisplayOrIgnorePickerError(err)
				return
			}

			scene.Terminate()
			scene = player.New(ptimer)
		}))

		appMenu.AddItem(appkit.NewMenuItemWithAction("Quit", "q", func(sender objc.Object) { app.Terminate(nil) }))

		appMenuItem.SetSubmenu(appMenu)

		menu.AddItem(appMenuItem)

		delegate.SetApplicationShouldTerminateAfterLastWindowClosed(func(app appkit.Application) bool {
			return true
		})
	})
}
