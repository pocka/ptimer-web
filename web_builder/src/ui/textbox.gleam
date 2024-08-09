// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/result
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import lustre/event
import storybook

// VIEW

pub type State(msg) {
  /// User can edit and type
  Enabled(on_input: fn(String) -> msg)

  Disabled
}

fn set_state_attrs(
  attrs: List(Attribute(msg)),
  state: State(msg),
) -> List(Attribute(msg)) {
  case state {
    Enabled(on_input) -> [event.on_input(on_input), ..attrs]

    Disabled ->
      // Lustre seems not to have a way to fix `value` property, thus this can't use
      // `aria-disabled` with `event.prevent_default`.
      [attribute.disabled(True), ..attrs]
  }
}

@external(javascript, "@/ui/textbox.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn textbox(
  value: String,
  state: State(msg),
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  html.input(
    [
      class(scoped("textbox")),
      attribute.property("value", value),
      attribute.type_("text"),
      ..attrs
    ]
    |> set_state_attrs(state),
  )
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let default_value =
    flags |> dynamic.field("defaultValue", dynamic.string) |> result.unwrap("")

  let state = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled

    _ -> Enabled(fn(value) { #("on_input", value) })
  }

  let _ =
    lustre.simple(
      fn(_) { default_value },
      fn(a, b: #(String, String)) {
        action(b.0, dynamic.from(b.1))
        a
      },
      fn(value) { textbox(value, state, []) },
    )
    |> lustre.start(selector, flags)

  Nil
}
