// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import storybook
import ui/textbox

// VIEW

@external(javascript, "@/ui/field.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  id id: String,
  label label: List(element.Element(msg)),
  input input: fn(List(Attribute(msg))) -> element.Element(msg),
  note note: Option(List(element.Element(msg))),
  attrs attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  let note_id = id <> "__note"

  html.div([class(scoped("field")), ..attrs], [
    html.label([attribute.for(id), class(scoped("label"))], label),
    input([
      attribute.id(id),
      case note {
        Some(_) -> attribute.attribute("aria-describedby", note_id)

        None -> attribute.none()
      },
    ]),
    case note {
      Some(children) ->
        html.p([attribute.id(note_id), class(scoped("note"))], children)

      None -> element.none()
    },
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

  let label = case flags |> dynamic.field("label", dynamic.string) {
    Ok(str) -> [element.text(str)]

    _ -> [element.text("Story Sample")]
  }

  let note = case flags |> dynamic.field("note", dynamic.string) {
    Ok("") -> None

    Ok(str) -> Some([element.text(str)])

    _ -> None
  }

  let _ =
    lustre.simple(fn(_) { Nil }, fn(a, _) { a }, fn(_) {
      view(
        id: "story_sample",
        label: label,
        input: textbox.textbox(
          "",
          textbox.Enabled(function.identity),
          textbox.SingleLine,
          _,
        ),
        note: note,
        attrs: [],
      )
    })
    |> lustre.start(selector, Nil)

  Nil
}
