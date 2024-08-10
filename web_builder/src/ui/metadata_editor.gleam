// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/option.{None, Some}
import gleam/result
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import ptimer
import storybook
import ui/textbox

// VIEW

@external(javascript, "@/ui/metadata_editor.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  timer: ptimer.Ptimer,
  on_update: fn(ptimer.Ptimer) -> msg,
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  let metadata = timer.metadata

  html.div([], [
    html.div([class(scoped("form")), ..attrs], [
      html.div([class(scoped("field"))], [
        html.label([attribute.for("metadata_title")], [element.text("Title")]),
        textbox.textbox(
          metadata.title,
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: ptimer.Metadata(..metadata, title: value),
              ),
            )
          }),
          textbox.SingleLine,
          [attribute.id("metadata_title")],
        ),
      ]),
      html.div([class(scoped("field"))], [
        html.label([attribute.for("metadata_description")], [
          element.text("Description"),
        ]),
        textbox.textbox(
          metadata.description |> option.unwrap(""),
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: ptimer.Metadata(
                  ..metadata,
                  description: case value {
                    "" -> None

                    str -> Some(str)
                  },
                ),
              ),
            )
          }),
          textbox.MultiLine(Some(4)),
          [attribute.id("metadata_description")],
        ),
      ]),
      html.div([class(scoped("field"))], [
        html.label([attribute.for("metadata_lang")], [
          element.text("Language Code"),
        ]),
        textbox.textbox(
          metadata.lang,
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: ptimer.Metadata(..metadata, lang: value),
              ),
            )
          }),
          textbox.SingleLine,
          [attribute.id("metadata_lang")],
        ),
      ]),
    ]),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let is_empty =
    flags
    |> dynamic.field("empty", dynamic.bool)
    |> result.unwrap(False)

  let _ =
    lustre.simple(
      fn(_) {
        case is_empty {
          True -> ptimer.empty

          False ->
            ptimer.Ptimer(
              metadata: ptimer.Metadata(
                title: "Sample timer",
                description: Some("Description"),
                lang: "en-GB",
              ),
              steps: [],
              assets: [],
            )
        }
      },
      fn(_, new_timer) {
        action("on_update", dynamic.from(new_timer))
        new_timer
      },
      fn(timer) { view(timer, function.identity, []) },
    )
    |> lustre.start(selector, Nil)

  Nil
}
