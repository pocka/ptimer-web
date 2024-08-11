// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/option.{type Option, None, Some}
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

pub type Mode {
  SingleLine
  MultiLine(rows: Option(Int))
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
  mode: Mode,
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  case mode {
    SingleLine ->
      html.input(
        [
          class(scoped("textbox")),
          attribute.property("value", value),
          attribute.type_("text"),
          ..attrs
        ]
        |> set_state_attrs(state),
      )
    MultiLine(rows) ->
      html.textarea(
        [
          class(scoped("textbox")),
          class(scoped("multiline")),
          case rows {
            Some(n) -> attribute.rows(n)
            None -> class(scoped("resizable-y"))
          },
          ..attrs
        ]
          |> set_state_attrs(state),
        value,
      )
  }
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let default_value =
    flags |> dynamic.field("defaultValue", dynamic.string) |> result.unwrap("")

  let rows = flags |> dynamic.field("rows", dynamic.int) |> result.unwrap(1)

  let resizable =
    flags |> dynamic.field("resize", dynamic.bool) |> result.unwrap(False)

  let mode = case flags |> dynamic.field("multiline", dynamic.bool) {
    Ok(True) ->
      MultiLine(case resizable {
        True -> None
        False -> Some(rows)
      })

    _ -> SingleLine
  }

  let state = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled

    _ -> Enabled(fn(value) { #("on_input", value) })
  }

  let _ =
    lustre.simple(
      fn(_) { default_value },
      fn(_, b: #(String, String)) {
        action(b.0, dynamic.from(b.1))
        b.1
      },
      fn(value) { textbox(value, state, mode, []) },
    )
    |> lustre.start(selector, flags)

  Nil
}
