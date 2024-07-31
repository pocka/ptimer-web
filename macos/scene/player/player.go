// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package player

import (
	"fmt"

	"github.com/progrium/darwinkit/helper/action"
	"github.com/progrium/darwinkit/helper/layout"
	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/macos/foundation"
	"github.com/progrium/darwinkit/objc"

	"github.com/pocka/ptimer/ptimer"
)

type state interface {
	Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView
}

type beforeStart struct{}

func (s *beforeStart) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	title := appkit.TextField_WrappingLabelWithString(timer.Metadata.Title)
	title.SetControlSize(appkit.ControlSizeLarge)
	title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

	view := appkit.StackView_StackViewWithViews([]appkit.IView{title})
	view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
	view.SetDistribution(appkit.StackViewDistributionFill)
	view.SetAlignment(appkit.LayoutAttributeLeading)
	view.SetSpacing(8)

	if timer.Metadata.Description != nil {
		description := appkit.TextField_WrappingLabelWithString(*timer.Metadata.Description)
		view.AddArrangedSubview(description)
	}

	padding := appkit.NewView()
	view.AddArrangedSubview(padding)

	next := appkit.NewButtonWithTitle("Start")
	next.SetKeyEquivalent("\r")
	next.SetControlSize(appkit.ControlSizeLarge)
	action.Set(next, func(sender objc.Object) {
		if len(timer.Steps) > 0 {
			moveTo(&playing{stepIndex: 0})
		} else {
			moveTo(&allStepsDone{})
		}
	})

	actions := appkit.StackView_StackViewWithViews([]appkit.IView{next})
	actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
	actions.SetAlignment(appkit.LayoutAttributeTrailing)
	view.AddArrangedSubview(actions)

	return &view
}

type playing struct {
	stepIndex uint
}

func (s *playing) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	children := make([]appkit.IView, 0, 3)

	if s.stepIndex < uint(len(timer.Steps)) {
		step := timer.Steps[s.stepIndex]

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
				nextIndex := s.stepIndex + 1

				if nextIndex >= uint(len(timer.Steps)) {
					moveTo(&allStepsDone{})
				} else {
					moveTo(&playing{stepIndex: nextIndex})
				}
			})

			actionsChildren = next
		} else {
			next := appkit.TextField_WrappingLabelWithString(fmt.Sprintf("Wait for %d seconds", *step.DurationSeconds))

			t := foundation.Timer_ScheduledTimerWithTimeIntervalRepeatsBlock(
				foundation.TimeInterval(*step.DurationSeconds),
				false,
				func(t foundation.Timer) {
					nextIndex := s.stepIndex + 1

					if nextIndex >= uint(len(timer.Steps)) {
						moveTo(&allStepsDone{})
					} else {
						moveTo(&playing{stepIndex: nextIndex})
					}
				},
			)
			objc.Retain(&t)

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

	return &view
}

type allStepsDone struct{}

func (s *allStepsDone) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	title := appkit.TextField_WrappingLabelWithString("Completed")
	title.SetControlSize(appkit.ControlSizeLarge)
	title.SetFont(appkit.Font_BoldSystemFontOfSize(16))

	next := appkit.NewButtonWithTitle("Back to start")
	next.SetKeyEquivalent("\r")
	next.SetControlSize(appkit.ControlSizeLarge)
	action.Set(next, func(sender objc.Object) {
		moveTo(&beforeStart{})
	})

	actions := appkit.StackView_StackViewWithViews([]appkit.IView{next})
	actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
	actions.SetAlignment(appkit.LayoutAttributeTrailing)

	view := appkit.StackView_StackViewWithViews([]appkit.IView{title, actions})
	view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
	view.SetDistribution(appkit.StackViewDistributionFill)
	view.SetAlignment(appkit.LayoutAttributeLeading)
	view.SetSpacing(8)

	return &view
}

type playerScene struct {
	ptimer *ptimer.Ptimer

	window appkit.Window

	state state

	isTerminated bool
}

func (s *playerScene) Terminate() {
	s.isTerminated = true
	s.window.Close()
}

func (s *playerScene) update() {
	if s.isTerminated {
		return
	}

	view := s.state.Render(s.ptimer, func(to state) {
		s.state = to
		s.update()
	})

	s.window.ContentView().SetSubviews([]appkit.IView{view})
	layout.PinEdgesToSuperView(view, foundation.EdgeInsets{Top: 8, Bottom: 8, Left: 16, Right: 16})
}

func New(timer *ptimer.Ptimer) *playerScene {
	window := appkit.NewWindowWithSizeAndStyle(
		320,
		160,
		appkit.WindowStyleMaskClosable|
			appkit.WindowStyleMaskTitled|
			appkit.WindowStyleMaskResizable|
			appkit.WindowStyleMaskMiniaturizable,
	)
	objc.Retain(&window)
	window.SetTitle(fmt.Sprintf("%s - Ptimer", timer.Metadata.Title))

	scene := playerScene{
		window:       window,
		ptimer:       timer,
		state:        &beforeStart{},
		isTerminated: false,
	}
	scene.update()

	window.MakeKeyAndOrderFront(nil)
	window.Center()

	return &scene
}
