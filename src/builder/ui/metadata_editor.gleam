// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/ui/field
import builder/ui/textbox
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import ptimer
import ptimer/metadata
import storybook

// VIEW

@external(javascript, "@/builder/ui/metadata_editor.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  timer: ptimer.Ptimer,
  on_update: fn(ptimer.Ptimer) -> msg,
  err: Option(metadata.EncodeError),
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  let metadata = timer.metadata

  html.div([], [
    html.div([class(scoped("form")), ..attrs], [
      field.new(ptimer.field_to_id(ptimer.Metadata(metadata.Title)), {
        textbox.textbox(
          metadata.title,
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: metadata.Metadata(..metadata, title: value),
              ),
            )
          }),
          textbox.SingleLine,
          _,
        )
      })
        |> field.label([element.text("Title")])
        |> field.note([
          element.text(
            "Title text shown when a user open the .ptimer file. This will also be a generated filename.",
          ),
        ])
        |> field.validity(case err {
          Some(metadata.EncodeError(title: Some(metadata.EmptyTitle), ..)) ->
            field.Invalid([
              element.text("Timer title can't be empty. Give the timer a name."),
            ])
          Some(metadata.EncodeError(
            title: Some(metadata.TooLongTitle(max)),
            ..,
          )) ->
            field.Invalid([
              element.text(
                "This timer title is too long. Shorten to "
                <> int.to_string(max)
                <> " characters at most.",
              ),
            ])
          _ -> field.Valid
        })
        |> field.view(attrs: []),
      field.new(ptimer.field_to_id(ptimer.Metadata(metadata.Description)), {
        textbox.textbox(
          metadata.description |> option.unwrap(""),
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: metadata.Metadata(
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
          _,
        )
      })
        |> field.label([element.text("Description")])
        |> field.view(attrs: []),
      field.new(ptimer.field_to_id(ptimer.Metadata(metadata.Lang)), {
        textbox.textbox(
          metadata.lang,
          textbox.Enabled(fn(value) {
            on_update(
              ptimer.Ptimer(
                ..timer,
                metadata: metadata.Metadata(..metadata, lang: value),
              ),
            )
          }),
          textbox.SingleLine,
          _,
        )
      })
        |> field.label([element.text("Language Code")])
        |> field.note([
          html.a(
            [
              class(scoped("link")),
              attribute.href("https://en.wikipedia.org/wiki/IETF_language_tag"),
              attribute.target("_blank"),
              attribute.rel("noopener"),
            ],
            [element.text("Language Code (IETF BCP 47 language tag)")],
          ),
          element.text(
            " of this timer file. For example, if you write titles and descriptions in English (US), type \"en-US\".",
          ),
        ])
        |> field.validity(case err {
          Some(metadata.EncodeError(lang: Some(metadata.EmptyLang), ..)) ->
            field.Invalid([
              element.text(
                "Language Code can't be empty. "
                <> " Language Code helps assistive applications such as screen readers.",
              ),
            ])
          _ -> field.Valid
        })
        |> field.view(attrs: []),
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
        let timer = case is_empty {
          True -> ptimer.empty

          False ->
            ptimer.Ptimer(
              metadata: metadata.Metadata(
                version: "1.0",
                title: "Sample timer",
                description: Some("Description"),
                lang: "en-GB",
              ),
              steps: [],
              assets: [],
            )
        }

        #(timer, ptimer.encode(timer))
      },
      fn(_, new_timer) {
        action("on_update", dynamic.from(new_timer))
        #(new_timer, ptimer.encode(new_timer))
      },
      fn(model) {
        let #(timer, encoded) = model

        view(
          timer,
          function.identity,
          encoded
            |> result.map_error(Some)
            |> result.unwrap_error(None)
            |> option.then(fn(err) { err.metadata }),
          [],
        )
      },
    )
    |> lustre.start(selector, Nil)

  Nil
}
