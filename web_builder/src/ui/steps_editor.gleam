// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import lucide
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element
import lustre/element/html
import ptimer
import storybook
import ui/button
import ui/textbox

// VIEW

@external(javascript, "@/ui/steps_editor.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  timer: ptimer.Ptimer,
  on_update: fn(ptimer.Ptimer) -> msg,
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  html.div(attrs, [
    html.div([class(scoped("container"))], [
      html.ol(
        [class(scoped("list"))],
        list.index_map(timer.steps, fn(step, i) {
          let id_prefix = "step_" <> int.to_string(i) <> "_"

          html.li([class(scoped("step"))], [
            html.div([class(scoped("step-header"))], [
              lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
              html.span([], [element.text(int.to_string(i + 1))]),
              lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
            ]),
            html.div([class(scoped("step-body"))], [
              html.label([attribute.for(id_prefix <> "title")], [
                element.text("Title"),
              ]),
              textbox.textbox(
                step.title,
                textbox.Enabled(fn(title) {
                  on_update(
                    ptimer.Ptimer(
                      ..timer,
                      steps: list.map(timer.steps, fn(a) {
                        case a == step {
                          True -> ptimer.Step(..step, title:)
                          False -> a
                        }
                      }),
                    ),
                  )
                }),
                textbox.SingleLine,
                [attribute.id(id_prefix <> "title")],
              ),
              html.label([attribute.for(id_prefix <> "description")], [
                element.text("Description"),
              ]),
              textbox.textbox(
                step.description |> option.unwrap(""),
                textbox.Enabled(fn(description) {
                  on_update(
                    ptimer.Ptimer(
                      ..timer,
                      steps: list.map(timer.steps, fn(a) {
                        case a == step {
                          True ->
                            ptimer.Step(
                              ..step,
                              description: case description {
                                "" -> None
                                str -> Some(str)
                              },
                            )
                          False -> a
                        }
                      }),
                    ),
                  )
                }),
                textbox.MultiLine(Some(3)),
                [attribute.id(id_prefix <> "description")],
              ),
            ]),
          ])
        }),
      ),
      button.button(
        button.Primary,
        button.Enabled(on_update(
          ptimer.Ptimer(
            ..timer,
            steps: list.append(timer.steps, [
              ptimer.Step(
                title: "",
                description: None,
                sound: None,
                action: ptimer.UserAction,
              ),
            ]),
          ),
        )),
        [],
        [element.text("Add step")],
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
        case is_empty {
          True -> ptimer.empty

          False ->
            ptimer.Ptimer(
              metadata: ptimer.Metadata(
                title: "Sample Timer",
                description: None,
                lang: "en-US",
              ),
              steps: [
                ptimer.Step(
                  title: "First Step",
                  description: None,
                  sound: None,
                  action: ptimer.UserAction,
                ),
                ptimer.Step(
                  title: "Second Step",
                  description: None,
                  sound: None,
                  action: ptimer.Timer(3),
                ),
              ],
              assets: [],
            )
        }
      },
      fn(_, new_timer) {
        action("on_update", dynamic.from(new_timer))
        new_timer
      },
      view(_, function.identity, []),
    )
    |> lustre.start(selector, Nil)

  Nil
}
