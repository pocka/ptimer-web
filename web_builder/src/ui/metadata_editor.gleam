// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/option.{None, Some}
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import lustre/event
import ptimer

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
        html.input([
          attribute.id("metadata_title"),
          attribute.type_("text"),
          attribute.value(metadata.title),
          event.on_input(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: ptimer.Metadata(..metadata, title: value),
              ),
            )
          }),
        ]),
      ]),
      html.div([class(scoped("field"))], [
        html.label([attribute.for("metadata_description")], [
          element.text("Description"),
        ]),
        html.textarea(
          [
            attribute.id("metadata_description"),
            event.on_input(fn(value) {
              on_update(
                ptimer.Ptimer(
                  ..timer,
                  metadata: ptimer.Metadata(
                    ..metadata,
                    description: case value {
                      "" -> None

                      v -> Some(v)
                    },
                  ),
                ),
              )
            }),
          ],
          metadata.description |> option.unwrap(""),
        ),
      ]),
      html.div([class(scoped("field"))], [
        html.label([attribute.for("metadata_lang")], [
          element.text("Language Code"),
        ]),
        html.input([
          attribute.id("metadata_lang"),
          attribute.type_("text"),
          attribute.value(metadata.lang),
          event.on_input(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: ptimer.Metadata(..metadata, lang: value),
              ),
            )
          }),
        ]),
      ]),
    ]),
  ])
}
