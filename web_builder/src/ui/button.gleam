// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import lustre/event
import storybook

// VIEW

@external(javascript, "@/ui/button.ffi.ts", "className")
fn scoped(x: String) -> String

pub type State(msg) {
  /// User can press the button.
  Enabled(on_click: msg)

  /// User can't press the button.
  Disabled(reason: Option(String))

  /// An action the button triggers is running. User can't press the button.
  Loading(description: Option(String))
}

fn set_state_attrs(
  attrs: List(attribute.Attribute(msg)),
  state: State(msg),
) -> List(attribute.Attribute(msg)) {
  case state {
    Enabled(msg) -> [event.on_click(msg), ..attrs]

    Disabled(_) -> [attribute.attribute("aria-disabled", "true"), ..attrs]

    Loading(_) -> [
      attribute.attribute("aria-disabled", "true"),
      class(scoped("loading")),
      ..attrs
    ]
  }
}

fn state_text(state: State(msg)) -> element.Element(msg) {
  case state {
    Disabled(Some(reason)) ->
      html.span([class(scoped("visually-hidden"))], [element.text(reason)])

    Loading(Some(description)) ->
      html.span([class(scoped("visually-hidden"))], [element.text(description)])

    _ -> element.none()
  }
}

pub type Variant {
  /// Prioritized button, the screen's primary action.
  Primary

  /// The button is not prioritized.
  Normal
}

fn set_variant_attrs(
  attrs: List(attribute.Attribute(msg)),
  variant: Variant,
) -> List(attribute.Attribute(msg)) {
  case variant {
    Primary -> [class(scoped("primary")), ..attrs]

    Normal -> [class(scoped("normal")), ..attrs]
  }
}

pub fn button(
  variant: Variant,
  state: State(msg),
  attrs: List(attribute.Attribute(msg)),
  children: List(element.Element(msg)),
) -> element.Element(msg) {
  let final_attrs =
    attrs
    |> list.prepend(class(scoped("button")))
    |> set_variant_attrs(variant)
    |> set_state_attrs(state)

  html.button(final_attrs, [html.span([], children), state_text(state)])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let variant = case flags |> dynamic.field("variant", dynamic.string) {
    Ok("primary") -> Primary

    _ -> Normal
  }

  let state = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled(None)

    Ok("loading") -> Loading(None)

    _ -> Enabled("onClick")
  }

  let _ =
    lustre.simple(
      function.identity,
      fn(a, b) {
        action("story_update", dynamic.from(b))
        a
      },
      fn(_) { button(variant, state, [], [element.text("Hello, Storybook!")]) },
    )
    |> lustre.start(selector, flags)

  Nil
}
