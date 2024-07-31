// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package wizard

import (
	"fmt"

	"github.com/progrium/darwinkit/macos/appkit"
	"github.com/progrium/darwinkit/objc"
)

// Wizard style layout, consists of title, description (optional) and actions.
type Wizard struct {
	title       string
	description *string
	actions     []appkit.IView
}

func New(title string) *Wizard {
	return &Wizard{
		title:       title,
		description: nil,
		actions:     make([]appkit.IView, 0, 3),
	}
}

func (w *Wizard) SetDescription(description string) {
	w.description = &description
}

func (w *Wizard) AddAction(view appkit.IView) error {
	if view == nil {
		return nil
	}

	if len(w.actions) >= cap(w.actions) {
		return fmt.Errorf("Cannot add more than %d actions", cap(w.actions))
	}

	objc.Retain(view)
	w.actions = append(w.actions, view)
	return nil
}

// Render contents into view.
func (w *Wizard) Render() appkit.IView {
	children := make([]appkit.IView, 0, 3)

	title := appkit.TextField_WrappingLabelWithString(w.title)
	title.SetControlSize(appkit.ControlSizeLarge)
	title.SetFont(appkit.Font_BoldSystemFontOfSize(16))
	objc.Retain(&title)
	children = append(children, &title)

	if w.description != nil {
		description := appkit.TextField_WrappingLabelWithString(*w.description)
		objc.Retain(&description)
		children = append(children, &description)
	}

	actions := appkit.StackView_StackViewWithViews(w.actions)
	actions.SetOrientation(appkit.UserInterfaceLayoutOrientationHorizontal)
	actions.SetAlignment(appkit.LayoutAttributeTrailing)
	objc.Retain(&actions)
	children = append(children, &actions)

	view := appkit.StackView_StackViewWithViews(children)
	view.SetOrientation(appkit.UserInterfaceLayoutOrientationVertical)
	view.SetDistribution(appkit.StackViewDistributionFill)
	view.SetAlignment(appkit.LayoutAttributeLeading)
	view.SetSpacing(8)
	objc.Retain(&view)

	return &view
}
