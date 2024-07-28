// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"database/sql"
	"fmt"

	"github.com/progrium/darwinkit/helper/action"
	"github.com/progrium/darwinkit/helper/layout"
	"github.com/progrium/darwinkit/macos"
	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/macos/foundation"
	"github.com/progrium/darwinkit/macos/uti"
	"github.com/progrium/darwinkit/objc"

	_ "modernc.org/sqlite"
)

func main() {
	macos.RunApp(func(app appkit.Application, delegate *appkit.ApplicationDelegate) {
		app.SetActivationPolicy(appkit.ApplicationActivationPolicyRegular)

		var window appkit.Window

		window = showPickerWindow(func(ptimer *Ptimer) {
			window.Close()
			window = showPlayerWindow(ptimer)
		})

		menu := appkit.NewMenu()
		app.SetMainMenu(menu)

		appMenuItem := appkit.NewMenuItemWithSelector("", "", objc.Selector{})
		appMenu := appkit.NewMenuWithTitle("App")

		appMenu.AddItem(appkit.NewMenuItemWithAction("Open file", "o", func(objc.Object) {
			ptimer, err := showFilePicker()
			if err != nil {
				handleFilePickError(err)
				return
			}

			window.Close()
			window = showPlayerWindow(ptimer)
		}))

		appMenu.AddItem(appkit.NewMenuItemWithAction("Quit", "q", func(sender objc.Object) { app.Terminate(nil) }))

		appMenuItem.SetSubmenu(appMenu)

		menu.AddItem(appMenuItem)

		delegate.SetApplicationShouldTerminateAfterLastWindowClosed(func(app appkit.Application) bool {
			return true
		})
	})
}

func handleFilePickError(err error) {
	if _, ok := err.(*filePickCancellation); ok {
		return
	}

	alert := appkit.NewAlert()
	alert.SetMessageText(fmt.Sprintf("Unable to read ptimer file\n%s", err))
	_ = alert.RunModal()
}

func showPlayerWindow(ptimer *Ptimer) appkit.Window {
	window := appkit.NewWindowWithSizeAndStyle(
		320,
		160,
		appkit.WindowStyleMaskClosable|
			appkit.WindowStyleMaskTitled|
			appkit.WindowStyleMaskResizable|
			appkit.WindowStyleMaskMiniaturizable,
	)
	objc.Retain(&window)
	window.SetTitle(fmt.Sprintf("%s - Ptimer", ptimer.Metadata.Title))

	title := appkit.TextField_WrappingLabelWithString(ptimer.Metadata.Title)
	title.SetControlSize(appkit.ControlSizeLarge)
	title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

	view := appkit.StackView_StackViewWithViews([]appkit.IView{title})
	view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
	view.SetDistribution(appkit.StackViewDistributionFill)
	view.SetAlignment(appkit.LayoutAttributeLeading)
	view.SetSpacing(8)

	if ptimer.Metadata.Description != nil {
		description := appkit.TextField_WrappingLabelWithString(*ptimer.Metadata.Description)
		view.AddArrangedSubview(description)
	}

	padding := appkit.NewView()
	view.AddArrangedSubview(padding)

	// TODO: Implement player
	next := appkit.NewButtonWithTitle("Start")
	next.SetKeyEquivalent("\r")
	next.SetControlSize(appkit.ControlSizeLarge)

	actions := appkit.StackView_StackViewWithViews([]appkit.IView{next})
	actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
	actions.SetAlignment(appkit.LayoutAttributeTrailing)
	view.AddArrangedSubview(actions)

	window.ContentView().AddSubview(view)
	layout.PinEdgesToSuperView(view, foundation.EdgeInsets{Top: 8, Bottom: 8, Left: 16, Right: 16})

	window.MakeKeyAndOrderFront(nil)
	window.Center()

	return window
}

func showPickerWindow(onPick func(ptimer *Ptimer)) appkit.Window {
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
		ptimer, err := showFilePicker()
		if err != nil {
			handleFilePickError(err)
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

	return window
}

type Asset struct {
	ID     uint
	Name   string
	MIME   string
	Notice *string
}

type Step struct {
	ID              uint
	Title           string
	Description     *string
	Sound           *uint
	DurationSeconds *uint
}

type Metadata struct {
	Title       string
	Description *string
	Language    string
}

type Ptimer struct {
	db *sql.DB

	Metadata Metadata
	Steps    []Step
	Assets   []Asset
}

func readMetadata(db *sql.DB) (*Metadata, error) {
	rows, err := db.Query(`
		SELECT title, description, lang FROM metadata LIMIT 1;
	`)
	if err != nil {
		return nil, fmt.Errorf("Failed to read metadata record: %s", err)
	}

	defer rows.Close()

	if !rows.Next() {
		return nil, fmt.Errorf("No metadata record found")
	}

	var metadata Metadata

	if err := rows.Scan(&metadata.Title, &metadata.Description, &metadata.Language); err != nil {
		return nil, err
	}

	return &metadata, nil
}

func readSteps(db *sql.DB) ([]Step, error) {
	rows, err := db.Query(`
		SELECT
			id, title, description,
			duration_seconds, sound
		FROM step
		ORDER BY 'index' ASC;
	`)
	if err != nil {
		return nil, fmt.Errorf("Failed to read step records: %s", err)
	}

	defer rows.Close()

	var steps []Step

	for rows.Next() {
		var step Step

		if err := rows.Scan(
			&step.ID,
			&step.Title,
			&step.Description,
			&step.DurationSeconds,
			&step.Sound,
		); err != nil {
			return nil, fmt.Errorf("Failed to scan a step row: %s", err)
		}

		steps = append(steps, step)
	}

	return steps, nil
}

func readAssets(db *sql.DB) ([]Asset, error) {
	rows, err := db.Query(`
		SELECT
			id, name, mime, notice
		FROM asset;
	`)
	if err != nil {
		return nil, fmt.Errorf("Failed to read asset records: %s", err)
	}

	defer rows.Close()

	var assets []Asset

	for rows.Next() {
		var asset Asset

		if err := rows.Scan(
			&asset.ID,
			&asset.Name,
			&asset.MIME,
			&asset.Notice,
		); err != nil {
			return nil, fmt.Errorf("Failed to scan an asset row: %s", err)
		}

		assets = append(assets, asset)
	}

	return assets, nil
}

func fromFile(path string) (*Ptimer, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	defer db.Close()

	metadata, err := readMetadata(db)
	if err != nil {
		return nil, err
	}

	steps, err := readSteps(db)
	if err != nil {
		return nil, err
	}

	assets, err := readAssets(db)
	if err != nil {
		return nil, err
	}

	return &Ptimer{
		db:       db,
		Metadata: *metadata,
		Steps:    steps,
		Assets:   assets,
	}, nil
}

type filePickCancellation struct {
	modalResponse appkit.ModalResponse
}

func (f *filePickCancellation) Error() string {
	return "File picker modal is cancelled"
}

func showFilePicker() (*Ptimer, error) {
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

	return fromFile(path)
}
