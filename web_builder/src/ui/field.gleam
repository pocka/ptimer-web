// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element}
import lustre/element/html
import storybook
import ui/textbox

// VIEW

pub type NoteNotSet

pub type ValidityNotSet

pub type Validity(msg) {
  Valid
  Invalid(List(element.Element(msg)))
}

pub opaque type Config(msg, label, note, validity) {
  Config(
    id: String,
    input: fn(List(Attribute(msg))) -> Element(msg),
    label: label,
    note: Option(List(Element(msg))),
    validity: Validity(msg),
  )
}

pub fn new(
  id id: String,
  input input: fn(List(Attribute(msg))) -> Element(msg),
) -> Config(msg, Nil, NoteNotSet, ValidityNotSet) {
  Config(id, input, Nil, None, Valid)
}

pub fn label(
  config: Config(msg, Nil, note, validity),
  label: List(Element(msg)),
) -> Config(msg, List(Element(msg)), note, validity) {
  Config(
    id: config.id,
    input: config.input,
    label: label,
    note: config.note,
    validity: config.validity,
  )
}

pub fn validity(
  config: Config(msg, label, note, ValidityNotSet),
  validity: Validity(msg),
) -> Config(msg, label, note, Validity(msg)) {
  Config(
    id: config.id,
    input: config.input,
    label: config.label,
    note: config.note,
    validity: validity,
  )
}

pub fn note(
  config: Config(msg, label, NoteNotSet, validity),
  note: List(Element(msg)),
) -> Config(msg, label, List(Element(msg)), validity) {
  Config(
    id: config.id,
    input: config.input,
    label: config.label,
    note: Some(note),
    validity: config.validity,
  )
}

@external(javascript, "@/ui/field.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  config config: Config(msg, List(Element(msg)), note, validity),
  attrs attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  let note_id = config.id <> "__note"

  html.div([class(scoped("field")), ..attrs], [
    html.label([attribute.for(config.id), class(scoped("label"))], config.label),
    config.input([
      attribute.id(config.id),
      case config.validity {
        Invalid(_) -> attribute.attribute("aria-invalid", "true")
        Valid -> attribute.none()
      },
      case config.note {
        Some(_) -> attribute.attribute("aria-describedby", note_id)

        None -> attribute.none()
      },
    ]),
    case config.note, config.validity {
      _, Invalid(children) ->
        html.p(
          [
            attribute.id(note_id),
            class(scoped("note")),
            class(scoped("invalid")),
          ],
          children,
        )

      Some([]), _ -> element.none()

      Some(children), _ ->
        html.p([attribute.id(note_id), class(scoped("note"))], children)

      _, _ -> element.none()
    },
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

  let label_flag = case flags |> dynamic.field("label", dynamic.string) {
    Ok(str) -> [element.text(str)]

    _ -> [element.text("Story Sample")]
  }

  let note_f = fn(config: Config(msg, label, NoteNotSet, validity)) -> Config(
    msg,
    label,
    List(Element(msg)),
    validity,
  ) {
    let n: Config(msg, label, List(Element(msg)), validity) =
      Config(
        id: config.id,
        input: config.input,
        label: config.label,
        note: config.note,
        validity: config.validity,
      )

    case flags |> dynamic.field("note", dynamic.string) {
      Ok("") -> n

      Ok(str) -> note(config, [element.text(str)])

      _ -> n
    }
  }

  let validity_flag = case flags |> dynamic.field("invalid", dynamic.string) {
    Ok("") -> Valid

    Ok(str) -> Invalid([element.text(str)])

    _ -> Valid
  }

  let _ =
    lustre.simple(fn(_) { Nil }, fn(a, _) { a }, fn(_) {
      new("story_sample", {
        textbox.textbox(
          "",
          textbox.Enabled(function.identity),
          textbox.SingleLine,
          _,
        )
      })
      |> label(label_flag)
      |> note_f
      |> validity(validity_flag)
      |> view(attrs: [])
    })
    |> lustre.start(selector, Nil)

  Nil
}
