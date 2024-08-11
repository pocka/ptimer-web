// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import lucide
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import lustre/event
import storybook

// VIEW

pub type State(option, msg) {
  Enabled(on_change: fn(option) -> msg)

  Disabled
}

fn set_state_attrs(
  attrs: List(Attribute(msg)),
  state: State(option, msg),
  options: List(#(String, option)),
) -> List(Attribute(msg)) {
  case state {
    Enabled(on_change) -> [
      event.on("change", fn(ev) {
        use value <- result.try(dynamic.field(
          "currentTarget",
          dynamic.field("value", dynamic.string),
        )(ev))

        case list.find(options, fn(option) { option.0 == value }) {
          Ok(#(_, option)) -> Ok(on_change(option))

          _ -> Error([])
        }
      }),
      ..attrs
    ]

    Disabled -> [attribute.disabled(True), ..attrs]
  }
}

@external(javascript, "@/ui/selectbox.ffi.ts", "textboxClassName")
fn scoped_textbox(x: String) -> String

@external(javascript, "@/ui/selectbox.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn selectbox(
  selected: option,
  options: List(#(String, option)),
  state: State(option, msg),
  attrs: List(Attribute(msg)),
  wrapper_attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  html.div([class(scoped("wrapper")), ..wrapper_attrs], [
    html.select(
      [class(scoped("selectbox")), class(scoped_textbox("textbox")), ..attrs]
        |> set_state_attrs(state, options),
      list.map(options, fn(option) {
        html.option(
          [attribute.selected(option.1 == selected), attribute.value(option.0)],
          option.0,
        )
      }),
    ),
    lucide.icon(lucide.ChevronDown, [class(scoped("chevron"))]),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let options =
    flags
    |> dynamic.field("options", dynamic.list(dynamic.string))
    |> result.unwrap([])

  let selected =
    flags |> dynamic.field("defaultValue", dynamic.string) |> result.unwrap("")

  let state = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled

    _ -> Enabled(fn(value) { #("on_change", value) })
  }

  let _ =
    lustre.simple(
      fn(_) { Some(selected) },
      fn(a, b: #(String, Option(String))) {
        action(b.0, dynamic.from(b.1))
        a
      },
      selectbox(_, options |> list.map(fn(x) { #(x, Some(x)) }), state, [], []),
    )
    |> lustre.start(selector, Nil)

  Nil
}
