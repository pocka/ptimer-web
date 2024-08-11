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
import ui/field
import ui/int_input
import ui/placeholder
import ui/selectbox
import ui/textbox

// VIEW

@external(javascript, "@/ui/steps_editor.ffi.ts", "className")
fn scoped(x: String) -> String

fn insert_at_recur(items: List(a), new_item: a, at: Int, index: Int) -> List(a) {
  case items, index == at {
    [], _ -> []

    [head, ..tail], True -> [new_item, head, ..tail]

    [head, ..tail], False -> [
      head,
      ..insert_at_recur(tail, new_item, at, index + 1)
    ]
  }
}

fn insert_at(items: List(a), new_item: a, at at: Int) -> List(a) {
  insert_at_recur(items, new_item, at, 0)
}

fn remove_at_recur(items: List(a), at: Int, index: Int) -> List(a) {
  case items, index == at {
    [], _ -> []

    [_, ..tail], True -> tail

    [head, ..tail], False -> [head, ..remove_at_recur(tail, at, index + 1)]
  }
}

fn remove_at(items: List(a), at at: Int) -> List(a) {
  remove_at_recur(items, at, 0)
}

fn step_views(
  steps: List(ptimer.Step),
  timer: ptimer.Ptimer,
  on_update: fn(ptimer.Ptimer) -> msg,
  index: Int,
) -> List(element.Element(msg)) {
  case steps {
    [] -> [
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
        button.Medium,
        Some(lucide.ListPlus),
        [],
        [element.text("Add step")],
      ),
    ]

    [step, ..rest] -> {
      let id_prefix = "step_" <> int.to_string(index) <> "_"

      let update_step = fn(payload: ptimer.Step) {
        on_update(
          ptimer.Ptimer(
            ..timer,
            steps: list.index_map(timer.steps, fn(a, j) {
              case index == j && a == step {
                True -> payload
                False -> a
              }
            }),
          ),
        )
      }

      [
        button.button(
          button.Normal,
          button.Enabled(on_update(
            ptimer.Ptimer(
              ..timer,
              steps: insert_at(
                timer.steps,
                ptimer.Step("", None, None, ptimer.UserAction),
                index,
              ),
            ),
          )),
          button.Medium,
          Some(lucide.ListPlus),
          [class(scoped("insert-button"))],
          [element.text("Insert step")],
        ),
        html.div([class(scoped("step"))], [
          html.div([class(scoped("step-header"))], [
            lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
            html.span([], [element.text(int.to_string(index + 1))]),
            lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
          ]),
          html.div([class(scoped("step-body"))], [
            field.view(
              id: id_prefix <> "title",
              label: [element.text("Title")],
              input: textbox.textbox(
                step.title,
                textbox.Enabled(fn(title) {
                  update_step(ptimer.Step(..step, title:))
                }),
                textbox.SingleLine,
                _,
              ),
              note: None,
              attrs: [],
            ),
            field.view(
              id: id_prefix <> "description",
              label: [element.text("Description")],
              input: textbox.textbox(
                step.description |> option.unwrap(""),
                textbox.Enabled(fn(description) {
                  update_step(
                    ptimer.Step(
                      ..step,
                      description: case description {
                        "" -> None
                        str -> Some(str)
                      },
                    ),
                  )
                }),
                textbox.MultiLine(Some(3)),
                _,
              ),
              note: None,
              attrs: [],
            ),
            html.div([class(scoped("action"))], [
              field.view(
                id: id_prefix <> "type",
                label: [element.text("Type")],
                input: selectbox.selectbox(
                  step.action,
                  [
                    #("UserAction", ptimer.UserAction),
                    #("Timer", case step.action {
                      ptimer.Timer(_) -> step.action

                      _ -> ptimer.Timer(3)
                    }),
                  ],
                  selectbox.Enabled(fn(option) {
                    update_step(ptimer.Step(..step, action: option))
                  }),
                  _,
                  [],
                ),
                note: case step.action {
                  ptimer.UserAction ->
                    Some([
                      element.text(
                        "The step displays a button, which completes the step on press.",
                      ),
                    ])

                  ptimer.Timer(_) ->
                    Some([
                      element.text(
                        "The step completes when a specified duration elapsed.",
                      ),
                    ])
                },
                attrs: [class(scoped("action-field"))],
              ),
              case step.action {
                ptimer.Timer(duration) ->
                  field.view(
                    id: id_prefix <> "duration",
                    label: [element.text("Duration")],
                    input: int_input.view(
                      duration,
                      int_input.Enabled(fn(n) {
                        update_step(
                          ptimer.Step(
                            ..step,
                            action: ptimer.Timer(int.clamp(
                              n,
                              min: 1,
                              max: 60 * 60 * 24,
                            )),
                          ),
                        )
                      }),
                      Some(element.text("secs.")),
                      _,
                      [],
                    ),
                    note: None,
                    attrs: [class(scoped("action-field"))],
                  )

                _ -> element.none()
              },
            ]),
            html.div([class(scoped("step-actions"))], [
              button.button(
                button.Normal,
                button.Enabled(on_update(
                  ptimer.Ptimer(..timer, steps: remove_at(timer.steps, index)),
                )),
                button.Small,
                Some(lucide.Trash2),
                [],
                [element.text("Delete")],
              ),
            ]),
          ]),
        ]),
        ..step_views(rest, timer, on_update, index + 1)
      ]
    }
  }
}

pub fn view(
  timer: ptimer.Ptimer,
  on_update: fn(ptimer.Ptimer) -> msg,
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  case timer.steps {
    [] ->
      placeholder.view(
        title: [element.text("No steps")],
        description: [
          element.text(
            "Timer file requires at least one step. Add a step to start.",
          ),
        ],
        actions: [
          button.button(
            button.Primary,
            button.Enabled(on_update(
              ptimer.Ptimer(
                ..timer,
                steps: [ptimer.Step("", None, None, ptimer.UserAction)],
              ),
            )),
            button.Medium,
            Some(lucide.ListPlus),
            [],
            [element.text("Add step")],
          ),
        ],
        attrs: [],
      )

    steps ->
      html.div(attrs, [
        html.div([class(scoped("container"))], [
          html.div(
            [class(scoped("list"))],
            step_views(steps, timer, on_update, 0),
          ),
        ]),
      ])
  }
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let steps =
    flags
    |> dynamic.field("steps", dynamic.list(ptimer.decode_step))
    |> result.unwrap([])

  let _ =
    lustre.simple(
      fn(_) {
        ptimer.Ptimer(
          metadata: ptimer.Metadata(
            title: "Sample Timer",
            description: None,
            lang: "en-US",
          ),
          steps:,
          assets: [],
        )
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
