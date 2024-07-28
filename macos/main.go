// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"github.com/progrium/darwinkit/helper/action"
	"github.com/progrium/darwinkit/helper/layout"
	"github.com/progrium/darwinkit/macos"
	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/macos/foundation"
	"github.com/progrium/darwinkit/macos/uti"
	"github.com/progrium/darwinkit/objc"
)

func main() {
	macos.RunApp(func(app appkit.Application, delegate *appkit.ApplicationDelegate) {
		app.SetActivationPolicy(appkit.ApplicationActivationPolicyRegular)

		// Content
		picker := showPickerWindow(app)

		// Menu
		menu := appkit.NewMenu()
		app.SetMainMenu(menu)

		appMenuItem := appkit.NewMenuItemWithSelector("", "", objc.Selector{})
		appMenu := appkit.NewMenuWithTitle("App")

		appMenu.AddItem(appkit.NewMenuItemWithAction("Open file", "o", func(objc.Object) {
			url := showFilePicker()
			if url == nil {
				return
			}

			picker.Close()
		}))

		appMenu.AddItem(appkit.NewMenuItemWithAction("Quit", "q", func(sender objc.Object) { app.Terminate(nil) }))

		appMenuItem.SetSubmenu(appMenu)

		menu.AddItem(appMenuItem)

		delegate.SetApplicationShouldTerminateAfterLastWindowClosed(func(appkit.Application) bool {
			return true
		})
	})
}

func showPickerWindow(appkit.Application) appkit.Window {
	window := appkit.NewWindow()
	window.SetTitle("Ptimer")

	openButton := appkit.NewButtonWithTitle("Select .ptimer file")

	action.Set(openButton, func(objc.Object) {
		url := showFilePicker()

		if url == nil {
			return
		}

		window.Close()
	})

	view := appkit.StackView_StackViewWithViews([]appkit.IView{openButton})
	view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
	view.SetDistribution(appkit.StackViewDistributionEqualCentering)
	view.SetAlignment(appkit.LayoutAttributeCenterX)
	view.SetSpacing(10)

	window.ContentView().AddSubview(view)
	layout.PinEdgesToSuperView(view, foundation.EdgeInsets{Top: 8, Bottom: 8, Left: 16, Right: 16})

	window.MakeKeyAndOrderFront(window)
	window.Center()

	return window
}

func showFilePicker() *string {
	panel := appkit.NewOpenPanel()

	panel.SetCanChooseDirectories(false)
	panel.SetCanChooseFiles(true)
	panel.SetAllowedContentTypes([]uti.IType{
		uti.Type_ExportedTypeWithIdentifier("com.github.pocka.ptimer.ptimer"),
		uti.TypeClass.TypeWithFilenameExtension("ptimer"),
	})

	res := panel.RunModal()
	if res != appkit.ModalResponseOK {
		return nil
	}

	url := panel.URL().AbsoluteString()

	return &url
}
