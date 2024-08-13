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
  Animate(msg: Msg)
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

    Internal(Animate(msg)), _ -> {
      #(model, flip("." <> scoped("flip-target"), msg))
    }

    UpdateSteps(_), _ -> #(Model(move_op: Idle), effect.none())

    _, _ -> #(model, effect.none())
  }
}

// EFFECTS

@external(javascript, "@/ui/steps_editor.ffi.ts", "runFLIP")
fn run_flip(query: String, on_update: fn() -> a) -> Nil

fn flip(query: String, msg: Msg) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use <- run_flip(query)

    dispatch(msg)
  })
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

@external(javascript, "@/ui/steps_editor.ffi.ts", "setDragEffect")
fn set_drag_effect(ev: dynamic.Dynamic, effect: String) -> Nil

fn move_before(
  steps: List(ptimer.Step),
  target target: ptimer.Step,
  anchor anchor: ptimer.Step,
) -> List(ptimer.Step) {
  case steps {
    [] -> []
    [head, ..tail] if head.id == target.id -> move_before(tail, target, anchor)
    [head, ..tail] if head.id == anchor.id -> [
      target,
      head,
      ..move_before(tail, target, anchor)
    ]
    [head, ..tail] -> [head, ..move_before(tail, target, anchor)]
  }
}

fn before_step(
  model: Model,
  timer: ptimer.Ptimer,
  step: Option(ptimer.Step),
  step_index index: Int,
  idle idle: element.Element(Msg),
) -> element.Element(Msg) {
  let move = fn(target: ptimer.Step) {
    Internal(
      Animate(
        UpdateSteps(case step {
          Some(step) -> timer.steps |> move_before(target: target, anchor: step)
          None ->
            timer.steps
            |> list.filter(fn(a) { a.id != target.id })
            |> list.append([target])
        }),
      ),
    )
  }

  case model.move_op {
    Idle -> idle

    ByButton(from, source) ->
      button.button(
        button.Normal,
        button.Enabled(move(source)),
        button.Medium,
        Some(lucide.CornerLeftDown),
        [
          case from == index || from == index - 1 {
            True -> class(scoped("invisible"))
            False -> attribute.none()
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

            Error([])
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

            Ok(move(source))
          }),
        ],
        [],
      )
  }
}

fn update_step(steps: List(ptimer.Step), step: ptimer.Step) -> List(ptimer.Step) {
  case steps {
    [] -> []
    [head, ..tail] if head.id == step.id -> [step, ..tail]
    [head, ..tail] -> [head, ..update_step(tail, step)]
  }
}

fn step_views(
  model: Model,
  steps: List(ptimer.Step),
  timer: ptimer.Ptimer,
  index: Int,
) -> List(#(String, element.Element(Msg))) {
  let next_id =
    timer.steps
    |> list.fold(None, fn(max, step) {
      case max {
        Some(id) if id >= step.id -> Some(id)
        _ -> Some(step.id)
      }
    })
    |> option.map(fn(a) { a + 1 })
    |> option.unwrap(0)

  case steps {
    [] -> [
      #(
        "before_step#last",
        before_step(
          model,
          timer,
          None,
          index,
          button.button(
            button.Primary,
            button.Enabled(UpdateSteps(
              timer.steps
              |> list.append([
                ptimer.Step(next_id, "", None, None, ptimer.UserAction),
              ]),
            )),
            button.Medium,
            Some(lucide.ListPlus),
            [class(scoped("flip-target"))],
            [element.text("Add step")],
          ),
        ),
      ),
    ]

    [step, ..rest] -> {
      let id_prefix = "step_" <> int.to_string(step.id) <> "_"

      [
        #(
          "before_step#" <> int.to_string(index),
          before_step(
            model,
            timer,
            Some(step),
            index,
            button.button(
              button.Normal,
              button.Enabled(
                Internal(
                  Animate(
                    UpdateSteps(insert_at(
                      timer.steps,
                      ptimer.Step(next_id, "", None, None, ptimer.UserAction),
                      index,
                    )),
                  ),
                ),
              ),
              button.Medium,
              Some(lucide.ListPlus),
              [class(scoped("insert-button"))],
              [element.text("Insert step")],
            ),
          ),
        ),
        #(
          "step#" <> int.to_string(step.id),
          html.div([class(scoped("step")), class(scoped("flip-target"))], [
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
                        UpdateSteps(update_step(
                          timer.steps,
                          ptimer.Step(..step, title:),
                        ))
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
                        UpdateSteps(update_step(
                          timer.steps,
                          ptimer.Step(
                            ..step,
                            description: case description {
                              "" -> None
                              str -> Some(str)
                            },
                          ),
                        ))
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
                          UpdateSteps(update_step(
                            timer.steps,
                            ptimer.Step(..step, action: option),
                          ))
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
                              UpdateSteps(update_step(
                                timer.steps,
                                ptimer.Step(
                                  ..step,
                                  action: ptimer.Timer(int.clamp(
                                    n,
                                    min: 1,
                                    max: 60 * 60 * 24,
                                  )),
                                ),
                              ))
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
                      button.Enabled(
                        Internal(
                          Animate(UpdateSteps(
                            timer.steps
                            |> list.filter(fn(a) { a.id != step.id }),
                          )),
                        ),
                      )

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
        ),
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
              UpdateSteps([ptimer.Step(0, "", None, None, ptimer.UserAction)]),
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
          element.keyed(
            html.div([class(scoped("list"))], _),
            step_views(model, steps, timer, 0),
          ),
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
