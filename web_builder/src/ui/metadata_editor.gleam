// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
import ui/field
import ui/textbox

// VIEW

@external(javascript, "@/ui/metadata_editor.ffi.ts", "className")
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
      field.view(
        id: "metadata_title",
        label: [element.text("Title")],
        input: textbox.textbox(
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
        ),
        note: Some([
          case option.then(err, fn(err) { err.title }) {
            Some(metadata.EmptyTitle) ->
              element.text("Timer title can't be empty. Give the timer a name.")
            Some(metadata.TooLongTitle(max)) ->
              element.text(
                "This timer title is too long. Shorten to "
                <> int.to_string(max)
                <> " characters at most.",
              )
            _ ->
              element.text(
                "Title text shown when a user open the .ptimer file. This will also be a generated filename.",
              )
          },
        ]),
        attrs: [],
      ),
      field.view(
        id: "metadata_description",
        label: [element.text("Description")],
        input: textbox.textbox(
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
        ),
        note: None,
        attrs: [],
      ),
      field.view(
        id: "metadata_lang",
        label: [element.text("Language Code")],
        input: textbox.textbox(
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
        ),
        note: Some(case option.then(err, fn(err) { err.lang }) {
          Some(metadata.EmptyLang) -> [
            element.text(
              "Language Code can't be empty. "
              <> " Language Code helps assistive applications such as screen readers.",
            ),
          ]
          None -> [
            html.a(
              [
                class(scoped("link")),
                attribute.href(
                  "https://en.wikipedia.org/wiki/IETF_language_tag",
                ),
                attribute.target("_blank"),
                attribute.rel("noopener"),
              ],
              [element.text("Language Code (IETF BCP 47 language tag)")],
            ),
            element.text(
              " of this timer file. For example, if you write titles and descriptions in English (US), type \"en-US\".",
            ),
          ]
        }),
        attrs: [],
      ),
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
