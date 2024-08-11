// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/int
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
  Enabled(on_input: fn(Int) -> msg)

  Disabled
}

@external(javascript, "@/ui/int_input.ffi.ts", "overwriteValue")
fn overwrite_value(ev: dynamic.Dynamic, value: String) -> Nil

fn set_state_attrs(
  attrs: List(Attribute(msg)),
  state: State(msg),
  value: Int,
) -> List(Attribute(msg)) {
  case state {
    Enabled(on_input) -> [
      // By returning an `Error` for non-integer values, this widget
      // invokes `on_update` with only valid integers (for correctness).
      // That means, the current `value` is the last correct integer
      // value.
      event.on("input", fn(ev) {
        ev
        |> dynamic.field(
          "currentTarget",
          dynamic.field("value", dynamic.string),
        )
        |> result.map(int.parse)
        |> result.map_error(fn(_) { Nil })
        |> result.flatten()
        |> result.map(on_input)
        |> result.map_error(fn(_) { [] })
      }),
      // Resets to the last valid `value` when leaving/submitting.
      // This let a user know the previous input value is invalid and
      // the application sees this value as a current value.
      // By only keeping correct value, we don't have to store `Result`s for each
      // integer properties.
      // This "reset-on-blur/enter" is superior to "immediate cast" method, such as
      // `int.parse(str) |> result.unwrap(SOME_SENSIBLE_VALUE)`:
      // * user can see invalid characters while typing, while `unwrap` method
      //   immediately resets to the `SOME_SENSIBLE_VALUE`, which is confusing.
      //   Without seeing invalid characters, user might not get an idea why
      //   the character they typed did not trigger an update.
      // * if a user type a floating number, for example `123.45`, decimal
      //   separator and fractional part is discarded while integer part (`123`)
      //   is kept.
      // However, this mechanism does not cover type-wise correct but semantically
      // incorrect values, such as out of valid range values.
      event.on("blur", fn(ev) {
        overwrite_value(ev, int.to_string(value))
        Error([])
      }),
      event.on("keyup", fn(ev) {
        case ev |> dynamic.field("key", dynamic.string) {
          Ok("Enter") -> overwrite_value(ev, int.to_string(value))

          _ -> Nil
        }

        Error([])
      }),
      ..attrs
    ]

    Disabled -> [attribute.disabled(True), ..attrs]
  }
}

@external(javascript, "@/ui/int_input.ffi.ts", "textboxClassName")
fn scoped_textbox(x: String) -> String

@external(javascript, "@/ui/int_input.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  value: Int,
  state: State(msg),
  unit: Option(element.Element(msg)),
  attrs: List(Attribute(msg)),
  wrapper_attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  html.div([class(scoped("wrapper")), ..wrapper_attrs], [
    html.input(
      [
        class(scoped_textbox("textbox")),
        // `<input type="number">` is dogshit: it returns empty `value` for invalid
        // values, displays ugly and most of the time useless spinner, not able to
        // specify format, etc...
        // By avoiding incorrect state and prioritizing p95 usecases, this project
        // uses plain `<input type="text">` with little bit of custom logic.
        attribute.type_("text"),
        attribute.attribute("inputmode", "decimal"),
        attribute.value(int.to_string(value)),
        ..attrs
      ]
      |> set_state_attrs(state, value),
    ),
    case unit {
      Some(text) -> html.span([class(scoped("unit"))], [text])

      None -> element.none()
    },
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let default_value =
    flags |> dynamic.field("defaultValue", dynamic.int) |> result.unwrap(0)

  let unit = case flags |> dynamic.field("unit", dynamic.string) {
    Ok("") -> None

    Ok(str) -> Some(element.text(str))

    _ -> None
  }

  let state = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled

    _ -> Enabled(fn(value) { #("on_input", value) })
  }

  let _ =
    lustre.simple(
      fn(_) { default_value },
      fn(_, b: #(String, Int)) {
        action(b.0, dynamic.from(b.1))
        b.1
      },
      view(_, state, unit, [], []),
    )
    |> lustre.start(selector, Nil)

  Nil
}
