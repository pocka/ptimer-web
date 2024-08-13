// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lucide
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import ptimer
import storybook
import ui/button
import ui/field
import ui/int_input
import ui/placeholder
import ui/selectbox
import ui/textbox

// MODEL

type MoveOperation {
  Idle
  ByButton(from: Int, source: ptimer.Step)
  ByDrag(from: Int, source: ptimer.Step, to: Option(Int))
}

pub opaque type Model {
  Model(move_op: MoveOperation)
}

pub fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model(move_op: Idle), effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  StartManualMove(from: Int, source: ptimer.Step)
  CancelManualMove
  StartDrag(from: Int, source: ptimer.Step)
  CancelDrag
  DragOver(index: Int)
  DragLeave(index: Int)
  NoOp
}

pub type Msg {
  UpdateSteps(List(ptimer.Step))

  Internal(InternalMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model {
    Internal(StartManualMove(from, source)), _ -> #(
      Model(move_op: ByButton(from, source)),
      effect.none(),
    )

    Internal(CancelManualMove), Model(move_op: ByButton(_, _)) -> #(
      Model(move_op: Idle),
      effect.none(),
    )

    Internal(StartDrag(from, source)), _ -> #(
      Model(move_op: ByDrag(from, source, None)),
      effect.none(),
    )

    Internal(CancelDrag), Model(move_op: ByDrag(_, _, _)) -> #(
      Model(move_op: Idle),
      effect.none(),
    )

    Internal(DragOver(index)), Model(move_op: ByDrag(from, source, _)) -> #(
      Model(move_op: ByDrag(from, source, Some(index))),
      effect.none(),
    )

    Internal(DragLeave(index)), Model(move_op: ByDrag(from, source, Some(to)))
      if index == to
    -> #(Model(move_op: ByDrag(from, source, None)), effect.none())

    UpdateSteps(_), _ -> #(Model(move_op: Idle), effect.none())

    _, _ -> #(model, effect.none())
  }
}

// VIEW

@external(javascript, "@/ui/steps_editor.ffi.ts", "className")
fn scoped(x: String) -> String

fn insert_at_recur(items: List(a), new_item: a, at: Int, index: Int) -> List(a) {
  case items, index == at {
    [], True -> [new_item]

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

@external(javascript, "@/ui/steps_editor.ffi.ts", "setDragEffect")
fn set_drag_effect(ev: dynamic.Dynamic, effect: String) -> Nil

fn before_step(
  model: Model,
  timer: ptimer.Ptimer,
  step_index index: Int,
  idle idle: element.Element(Msg),
) -> element.Element(Msg) {
  let move = fn(from: Int, source: ptimer.Step) {
    UpdateSteps(
      timer.steps
      |> list.index_map(fn(s, i) {
        case i == from {
          True -> None
          False -> Some(s)
        }
      })
      |> insert_at(Some(source), index)
      |> list.filter_map(option.to_result(_, Nil)),
    )
  }

  case model.move_op {
    Idle -> idle

    ByButton(from, source) ->
      button.button(
        button.Normal,
        button.Enabled(move(from, source)),
        button.Medium,
        Some(lucide.CornerLeftDown),
        [
          case from == index || from == index - 1 {
            True -> class(scoped("invisible"))
            False -> class(scoped("move-button"))
          },
        ],
        [element.text("Move to here")],
      )

    ByDrag(from, source, to) ->
      html.div(
        [
          class(scoped("drop-target")),
          case from == index || from == index - 1 {
            True -> class(scoped("invisible"))
            False -> attribute.none()
          },
          case to == Some(index) {
            True -> class(scoped("active"))
            False -> attribute.none()
          },
          event.on("dragover", fn(ev) {
            event.prevent_default(ev)

            Ok(Internal(NoOp))
          }),
          event.on("dragenter", fn(ev) {
            event.prevent_default(ev)

            Ok(Internal(DragOver(index)))
          }),
          event.on("dragleave", fn(ev) {
            event.prevent_default(ev)

            Ok(Internal(DragLeave(index)))
          }),
          event.on("drop", fn(ev) {
            event.prevent_default(ev)

            Ok(move(from, source))
          }),
        ],
        [],
      )
  }
}

fn step_views(
  model: Model,
  steps: List(ptimer.Step),
  timer: ptimer.Ptimer,
  index: Int,
) -> List(element.Element(Msg)) {
  case steps {
    [] -> [
      before_step(
        model,
        timer,
        index,
        button.button(
          button.Primary,
          button.Enabled(UpdateSteps(
            timer.steps
            |> list.append([ptimer.Step("", None, None, ptimer.UserAction)]),
          )),
          button.Medium,
          Some(lucide.ListPlus),
          [],
          [element.text("Add step")],
        ),
      ),
    ]

    [step, ..rest] -> {
      let id_prefix = "step_" <> int.to_string(index) <> "_"

      let update_step = fn(payload: ptimer.Step) {
        UpdateSteps(
          list.index_map(timer.steps, fn(a, j) {
            case index == j && a == step {
              True -> payload
              False -> a
            }
          }),
        )
      }

      [
        before_step(
          model,
          timer,
          index,
          button.button(
            button.Normal,
            button.Enabled(
              UpdateSteps(insert_at(
                timer.steps,
                ptimer.Step("", None, None, ptimer.UserAction),
                index,
              )),
            ),
            button.Medium,
            Some(lucide.ListPlus),
            [class(scoped("insert-button"))],
            [element.text("Insert step")],
          ),
        ),
        html.div([class(scoped("step"))], [
          html.div(
            [
              class(scoped("step-header")),
              attribute.attribute("draggable", "true"),
              event.on("dragend", fn(ev) {
                event.prevent_default(ev)

                Ok(Internal(CancelDrag))
              }),
              event.on("dragstart", fn(ev) {
                event.stop_propagation(ev)
                set_drag_effect(ev, "move")

                Ok(Internal(StartDrag(index, step)))
              }),
            ],
            [
              lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
              html.span([], [element.text(int.to_string(index + 1))]),
              lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
            ],
          ),
          html.div([class(scoped("step-body"))], [
            field.view(
              id: id_prefix <> "title",
              label: [element.text("Title")],
              input: textbox.textbox(
                step.title,
                case model.move_op {
                  Idle ->
                    textbox.Enabled(fn(title) {
                      update_step(ptimer.Step(..step, title:))
                    })

                  _ -> textbox.Disabled
                },
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
                case model.move_op {
                  Idle ->
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
                    })
                  _ -> textbox.Disabled
                },
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
                  case model.move_op {
                    Idle ->
                      selectbox.Enabled(fn(option) {
                        update_step(ptimer.Step(..step, action: option))
                      })
                    _ -> selectbox.Disabled
                  },
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
                      case model.move_op {
                        Idle ->
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
                          })
                        _ -> int_input.Disabled
                      },
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
              case model.move_op {
                Idle ->
                  button.button(
                    button.Normal,
                    button.Enabled(Internal(StartManualMove(index, step))),
                    button.Small,
                    Some(lucide.ArrowDownUp),
                    [],
                    [element.text("Move")],
                  )

                ByButton(from, _) if from == index ->
                  button.button(
                    button.Primary,
                    button.Enabled(Internal(CancelManualMove)),
                    button.Small,
                    Some(lucide.Ban),
                    [],
                    [element.text("Cancel")],
                  )

                _ ->
                  button.button(
                    button.Normal,
                    button.Disabled(None),
                    button.Small,
                    Some(lucide.ArrowDownUp),
                    [],
                    [element.text("Move")],
                  )
              },
              button.button(
                button.Normal,
                case model.move_op {
                  Idle ->
                    button.Enabled(UpdateSteps(remove_at(timer.steps, index)))

                  _ -> button.Disabled(None)
                },
                button.Small,
                Some(lucide.Trash2),
                [],
                [element.text("Delete")],
              ),
            ]),
          ]),
        ]),
        ..step_views(model, rest, timer, index + 1)
      ]
    }
  }
}

pub fn view(
  timer: ptimer.Ptimer,
  model: Model,
  attrs: List(Attribute(Msg)),
) -> element.Element(Msg) {
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
            button.Enabled(
              UpdateSteps([ptimer.Step("", None, None, ptimer.UserAction)]),
            ),
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
          html.div([class(scoped("list"))], step_views(model, steps, timer, 0)),
        ]),
      ])
  }
}

type StoryModel {
  StoryModel(timer: ptimer.Ptimer, model: Model)
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let story_update = fn(model: StoryModel, msg: Msg) -> #(
    StoryModel,
    effect.Effect(Msg),
  ) {
    case msg {
      UpdateSteps(steps) -> {
        action("UpdateSteps", dynamic.from(steps))

        let #(m, e) = update(model.model, msg)

        #(StoryModel(ptimer.Ptimer(..model.timer, steps:), m), e)
      }

      Internal(internal_msg) -> {
        action("Internal", dynamic.from(internal_msg))

        let #(m, e) = update(model.model, msg)

        #(StoryModel(model.timer, m), e)
      }
    }
  }

  let steps =
    flags
    |> dynamic.field("steps", dynamic.list(ptimer.decode_step))
    |> result.unwrap([])

  let _ =
    lustre.application(
      fn(_) {
        #(
          StoryModel(
            ptimer.Ptimer(
              metadata: ptimer.Metadata("Sample Story", None, "en-US"),
              steps:,
              assets: [],
            ),
            Model(move_op: Idle),
          ),
          effect.none(),
        )
      },
      story_update,
      fn(model) { view(model.timer, model.model, []) },
    )
    |> lustre.start(selector, Nil)

  Nil
}
