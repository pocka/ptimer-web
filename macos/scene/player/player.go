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
	"github.com/pocka/ptimer/widget/wizard"
)

type state interface {
	Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView

	Terminate()
}

type beforeStart struct{}

func (s *beforeStart) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	w := wizard.New(timer.Metadata.Title)

	if timer.Metadata.Description != nil {
		w.SetDescription(*timer.Metadata.Description)
	}

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
	w.AddAction(&next)

	return w.Render()
}

func (s *beforeStart) Terminate() {}

type playing struct {
	stepIndex uint

	timer *foundation.Timer
}

func (s *playing) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	if s.stepIndex >= uint(len(timer.Steps)) {
		w := wizard.New("Illegal step reached")

		next := appkit.NewButtonWithTitle("Done")
		next.SetKeyEquivalent("\r")
		next.SetControlSize(appkit.ControlSizeLarge)
		action.Set(next, func(sender objc.Object) {
			moveTo(&beforeStart{})
		})
		w.AddAction(&next)

		return w.Render()
	}

	step := timer.Steps[s.stepIndex]

	w := wizard.New(step.Title)

	if step.Description != nil {
		w.SetDescription(*step.Description)
	}

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
		w.AddAction(&next)
	} else {
		next := appkit.TextField_WrappingLabelWithString(fmt.Sprintf("Wait for %d seconds", *step.DurationSeconds))
		w.AddAction(&next)

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
		s.timer = &t
	}

	return w.Render()
}

func (s *playing) Terminate() {
	if s == nil {
		return
	}

	if s.timer != nil {
		s.timer.Invalidate()
		s.timer = nil
	}
}

type allStepsDone struct{}

func (s *allStepsDone) Render(timer *ptimer.Ptimer, moveTo func(state)) appkit.IView {
	w := wizard.New("Completed")
	w.SetDescription("All steps completed.")

	next := appkit.NewButtonWithTitle("Done")
	next.SetKeyEquivalent("\r")
	next.SetControlSize(appkit.ControlSizeLarge)
	action.Set(next, func(sender objc.Object) {
		moveTo(&beforeStart{})
	})
	w.AddAction(&next)

	return w.Render()
}

func (s *allStepsDone) Terminate() {}

type playerScene struct {
	ptimer *ptimer.Ptimer

	window *appkit.Window

	state state

	isTerminated bool
}

func (s *playerScene) Terminate() {
	if s == nil {
		return
	}

	if !s.isTerminated {
		s.state.Terminate()
		s.isTerminated = true
		s.window.Close()
	}
}

func (s *playerScene) update() {
	if s.isTerminated {
		return
	}

	view := s.state.Render(s.ptimer, func(to state) {
		s.state.Terminate()
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
		window:       &window,
		ptimer:       timer,
		state:        &beforeStart{},
		isTerminated: false,
	}
	scene.update()

	window.MakeKeyAndOrderFront(nil)
	window.Center()

	return &scene
}
