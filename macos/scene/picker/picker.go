// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package picker

import (
	"fmt"

	"github.com/progrium/darwinkit/helper/action"
	"github.com/progrium/darwinkit/helper/layout"
	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/macos/foundation"
	"github.com/progrium/darwinkit/macos/uti"
	"github.com/progrium/darwinkit/objc"

	"github.com/pocka/ptimer/ptimer"
)

type CancellationError struct {
	modalResponse appkit.ModalResponse
}

func (f *CancellationError) Error() string {
	return "File picker modal is cancelled"
}

func DisplayOrIgnorePickerError(err error) {
	if _, ok := err.(*CancellationError); ok {
		return
	}

	alert := appkit.NewAlert()
	alert.SetMessageText(fmt.Sprintf("Unable to read ptimer file\n%s", err))
	_ = alert.RunModal()
}

type pickerScene struct {
	window appkit.Window
}

func (s *pickerScene) Terminate() {
	s.window.Close()
}

func New(onPick func(timer *ptimer.Ptimer)) *pickerScene {
	window := appkit.NewWindowWithSizeAndStyle(
		150,
		70,
		appkit.WindowStyleMaskClosable|appkit.WindowStyleMaskTitled,
	)
	objc.Retain(&window)
	window.SetTitle("Ptimer")

	openButton := appkit.NewButtonWithTitle("Select .ptimer file")
	openButton.SetKeyEquivalent("\r")
	openButton.SetControlSize(appkit.ControlSizeLarge)

	action.Set(openButton, func(objc.Object) {
		ptimer, err := Show()
		if err != nil {
			DisplayOrIgnorePickerError(err)
			return
		}

		onPick(ptimer)
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

	return &pickerScene{
		window: window,
	}
}

type filePickCancellation struct {
	modalResponse appkit.ModalResponse
}

func (f *filePickCancellation) Error() string {
	return "File picker modal is cancelled"
}

func Show() (*ptimer.Ptimer, error) {
	panel := appkit.NewOpenPanel()

	panel.SetCanChooseDirectories(false)
	panel.SetCanChooseFiles(true)
	panel.SetAllowedContentTypes([]uti.IType{
		uti.Type_ExportedTypeWithIdentifier("com.github.pocka.ptimer.ptimer"),
		uti.TypeClass.TypeWithFilenameExtension("ptimer"),
	})

	res := panel.RunModal()
	if res != appkit.ModalResponseOK {
		return nil, &filePickCancellation{res}
	}

	path := panel.URL().AbsoluteString()

	return ptimer.NewFromFile(path)
}
