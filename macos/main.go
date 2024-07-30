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

type scene interface {
	Terminate()
}

func handleFilePickError(err error) {
	if _, ok := err.(*filePickCancellation); ok {
		return
	}

	alert := appkit.NewAlert()
	alert.SetMessageText(fmt.Sprintf("Unable to read ptimer file\n%s", err))
	_ = alert.RunModal()
}

func main() {
	macos.RunApp(func(app appkit.Application, delegate *appkit.ApplicationDelegate) {
		app.SetActivationPolicy(appkit.ApplicationActivationPolicyRegular)

		var scene scene

		scene = startPickerScene(func(ptimer *Ptimer) {
			scene.Terminate()
			scene = startPlayerScene(ptimer)
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

			scene.Terminate()
			scene = startPlayerScene(ptimer)
		}))

		appMenu.AddItem(appkit.NewMenuItemWithAction("Quit", "q", func(sender objc.Object) { app.Terminate(nil) }))

		appMenuItem.SetSubmenu(appMenu)

		menu.AddItem(appMenuItem)

		delegate.SetApplicationShouldTerminateAfterLastWindowClosed(func(app appkit.Application) bool {
			return true
		})
	})
}

type waitingStart struct{}

type playingStep struct {
	index uint
}

type allStepsDone struct{}

type playerScene struct {
	ptimer *Ptimer

	window appkit.Window

	state interface{}

	view appkit.IView
}

func (p *playerScene) Terminate() {
	p.window.Close()
}

func (p *playerScene) Render() {
	var newView appkit.IView

	switch state := p.state.(type) {
	case waitingStart:
		title := appkit.TextField_WrappingLabelWithString(p.ptimer.Metadata.Title)
		title.SetControlSize(appkit.ControlSizeLarge)
		title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

		view := appkit.StackView_StackViewWithViews([]appkit.IView{title})
		view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
		view.SetDistribution(appkit.StackViewDistributionFill)
		view.SetAlignment(appkit.LayoutAttributeLeading)
		view.SetSpacing(8)

		if p.ptimer.Metadata.Description != nil {
			description := appkit.TextField_WrappingLabelWithString(*p.ptimer.Metadata.Description)
			view.AddArrangedSubview(description)
		}

		padding := appkit.NewView()
		view.AddArrangedSubview(padding)

		next := appkit.NewButtonWithTitle("Start")
		next.SetKeyEquivalent("\r")
		next.SetControlSize(appkit.ControlSizeLarge)
		action.Set(next, func(sender objc.Object) {
			if len(p.ptimer.Steps) > 0 {
				p.state = playingStep{index: 0}
			} else {
				p.state = allStepsDone{}
			}

			p.Render()
		})

		actions := appkit.StackView_StackViewWithViews([]appkit.IView{next})
		actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
		actions.SetAlignment(appkit.LayoutAttributeTrailing)
		view.AddArrangedSubview(actions)

		newView = view
	case playingStep:
		children := make([]appkit.IView, 0, 3)

		if state.index < uint(len(p.ptimer.Steps)) {
			step := p.ptimer.Steps[state.index]

			title := appkit.TextField_WrappingLabelWithString(step.Title)
			title.SetControlSize(appkit.ControlSizeLarge)
			title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

			children = append(children, title)

			if step.Description != nil {
				description := appkit.TextField_WrappingLabelWithString(*step.Description)
				children = append(children, description)
			}

			var actionsChildren appkit.IView

			if step.DurationSeconds == nil {
				next := appkit.NewButtonWithTitle("Next")
				next.SetKeyEquivalent("\r")
				next.SetControlSize(appkit.ControlSizeLarge)
				action.Set(next, func(sender objc.Object) {
					nextIndex := state.index + 1

					if nextIndex >= uint(len(p.ptimer.Steps)) {
						p.state = allStepsDone{}
					} else {
						p.state = playingStep{index: nextIndex}
					}

					p.Render()
				})

				actionsChildren = next
			} else {
				next := appkit.TextField_WrappingLabelWithString(fmt.Sprintf("Wait for %d seconds", *step.DurationSeconds))

				timer := foundation.Timer_ScheduledTimerWithTimeIntervalRepeatsBlock(
					foundation.TimeInterval(*step.DurationSeconds),
					false,
					func(timer foundation.Timer) {
						nextIndex := state.index + 1

						if nextIndex >= uint(len(p.ptimer.Steps)) {
							p.state = allStepsDone{}
						} else {
							p.state = playingStep{index: nextIndex}
						}

						p.Render()
					},
				)
				objc.Retain(&timer)

				actionsChildren = next
			}

			actions := appkit.StackView_StackViewWithViews([]appkit.IView{actionsChildren})
			actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
			actions.SetAlignment(appkit.LayoutAttributeTrailing)

			children = append(children, actions)
		} else {
			text := appkit.TextField_WrappingLabelWithString("Illegal step reached")
			children = append(children, text)
		}

		view := appkit.StackView_StackViewWithViews(children)
		view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
		view.SetDistribution(appkit.StackViewDistributionFill)
		view.SetAlignment(appkit.LayoutAttributeLeading)
		view.SetSpacing(8)

		newView = view
	case allStepsDone:
		title := appkit.TextField_WrappingLabelWithString("Completed")
		title.SetControlSize(appkit.ControlSizeLarge)
		title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

		next := appkit.NewButtonWithTitle("Back to start")
		next.SetKeyEquivalent("\r")
		next.SetControlSize(appkit.ControlSizeLarge)
		action.Set(next, func(sender objc.Object) {
			p.state = waitingStart{}
			p.Render()
		})

		actions := appkit.StackView_StackViewWithViews([]appkit.IView{next})
		actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
		actions.SetAlignment(appkit.LayoutAttributeTrailing)

		view := appkit.StackView_StackViewWithViews([]appkit.IView{title, actions})
		view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
		view.SetDistribution(appkit.StackViewDistributionFill)
		view.SetAlignment(appkit.LayoutAttributeLeading)
		view.SetSpacing(8)

		newView = view
	}

	if newView == nil {
		return
	}

	if p.view != nil {
		p.window.ContentView().ReplaceSubviewWith(p.view, newView)
	} else {
		p.window.ContentView().AddSubview(newView)
	}

	p.view = newView
	layout.PinEdgesToSuperView(newView, foundation.EdgeInsets{Top: 8, Bottom: 8, Left: 16, Right: 16})
}

func startPlayerScene(ptimer *Ptimer) *playerScene {
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

	scene := playerScene{
		window: window,
		ptimer: ptimer,
		state:  waitingStart{},
	}
	scene.Render()

	window.MakeKeyAndOrderFront(nil)
	window.Center()

	return &scene
}

type pickerScene struct {
	window appkit.Window
}

func (s *pickerScene) Terminate() {
	s.window.Close()
}

func startPickerScene(onPick func(ptimer *Ptimer)) *pickerScene {
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

	return &pickerScene{
		window: window,
	}
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
