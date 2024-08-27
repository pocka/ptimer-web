// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/lucide
import builder/ptimer
import builder/ptimer/metadata
import builder/ptimer/step
import builder/storybook
import builder/ui/button
import builder/ui/field
import builder/ui/int_input
import builder/ui/placeholder
import builder/ui/selectbox
import builder/ui/textbox
import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

// MODEL

type MoveOperation {
  Idle
  ByButton(from: Int, source: step.Step)
  ByDrag(from: Int, source: step.Step, to: Option(Int))
}

pub opaque type Model {
  Model(move_op: MoveOperation)
}

pub fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model(move_op: Idle), effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  StartManualMove(from: Int, source: step.Step)
  CancelManualMove
  StartDrag(from: Int, source: step.Step)
  CancelDrag
  DragOver(index: Int)
  DragLeave(index: Int)
  Animate(msg: Msg)
  NoOp
}

pub type Msg {
  UpdateSteps(List(step.Step))

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

@external(javascript, "@/builder/ui/steps_editor.ffi.ts", "runFLIP")
fn run_flip(query: String, on_update: fn() -> a) -> Nil

fn flip(query: String, msg: Msg) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use <- run_flip(query)

    dispatch(msg)
  })
}

// VIEW

@external(javascript, "@/builder/ui/steps_editor.ffi.ts", "className")
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

@external(javascript, "@/builder/ui/steps_editor.ffi.ts", "configureDataTransfer")
fn configure_dragstart_event(ev: dynamic.Dynamic, effect: String) -> Nil

fn move_before(
  steps: List(step.Step),
  target target: step.Step,
  anchor anchor: step.Step,
) -> List(step.Step) {
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
  msg: fn(Msg) -> msg,
  model: Model,
  timer: ptimer.Ptimer,
  step: Option(step.Step),
  step_index index: Int,
  idle idle: element.Element(msg),
) -> element.Element(msg) {
  let move = fn(target: step.Step) {
    Animate(
      UpdateSteps(case step {
        Some(step) -> timer.steps |> move_before(target: target, anchor: step)
        None ->
          timer.steps
          |> list.filter(fn(a) { a.id != target.id })
          |> list.append([target])
      }),
    )
    |> Internal
    |> msg
  }

  case model.move_op {
    Idle -> idle

    ByButton(from, source) ->
      button.new(button.Button(move(source)))
      |> button.icon(lucide.CornerLeftDown)
      |> button.view(
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

            Ok(Internal(DragOver(index)) |> msg)
          }),
          event.on("dragleave", fn(ev) {
            event.prevent_default(ev)

            Ok(Internal(DragLeave(index)) |> msg)
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

fn update_step(steps: List(step.Step), step: step.Step) -> List(step.Step) {
  case steps {
    [] -> []
    [head, ..tail] if head.id == step.id -> [step, ..tail]
    [head, ..tail] -> [head, ..update_step(tail, step)]
  }
}

fn step_views(
  msg: fn(Msg) -> msg,
  model: Model,
  steps: List(step.Step),
  timer: ptimer.Ptimer,
  err: dict.Dict(Int, step.EncodeError),
  index: Int,
) -> List(#(String, element.Element(msg))) {
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
          msg,
          model,
          timer,
          None,
          index,
          button.new(button.Button(
            UpdateSteps(
              timer.steps
              |> list.append([
                step.Step(next_id, "", None, None, step.UserAction),
              ]),
            )
            |> msg,
          ))
            |> button.variant(button.Primary)
            |> button.icon(lucide.ListPlus)
            |> button.view([class(scoped("flip-target"))], [
              element.text("Add step"),
            ]),
        ),
      ),
    ]

    [step, ..rest] -> {
      let step_err = err |> dict.get(step.id) |> option.from_result

      [
        #(
          "before_step#" <> int.to_string(index),
          before_step(
            msg,
            model,
            timer,
            Some(step),
            index,
            button.new(button.Button(
              Internal(
                Animate(
                  UpdateSteps(insert_at(
                    timer.steps,
                    step.Step(next_id, "", None, None, step.UserAction),
                    index,
                  )),
                ),
              )
              |> msg,
            ))
              |> button.icon(lucide.ListPlus)
              |> button.view([class(scoped("insert-button"))], [
                element.text("Insert step"),
              ]),
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

                  Ok(Internal(CancelDrag) |> msg)
                }),
                event.on("dragstart", fn(ev) {
                  event.stop_propagation(ev)
                  configure_dragstart_event(ev, "move")

                  Ok(Internal(StartDrag(index, step)) |> msg)
                }),
              ],
              [
                lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
                html.span([], [element.text(int.to_string(index + 1))]),
                lucide.icon(lucide.GripHorizontal, [class(scoped("grip"))]),
              ],
            ),
            html.div([class(scoped("step-body"))], [
              field.new(ptimer.field_to_id(ptimer.Step(step.id, step.Title)), {
                textbox.textbox(
                  step.title,
                  case model.move_op {
                    Idle ->
                      textbox.Enabled(fn(title) {
                        UpdateSteps(update_step(
                          timer.steps,
                          step.Step(..step, title:),
                        ))
                        |> msg
                      })

                    _ -> textbox.Disabled
                  },
                  textbox.SingleLine,
                  _,
                )
              })
                |> field.label([element.text("Title")])
                |> field.validity(case step_err {
                  Some(step.EncodeError(title: Some(step.EmptyTitle), ..)) ->
                    field.Invalid([element.text("Step title can't be empty.")])
                  Some(step.EncodeError(
                    title: Some(step.TooLongTitle(max)),
                    ..,
                  )) ->
                    field.Invalid([
                      element.text(
                        "This step title is too long. Shorten to "
                        <> int.to_string(max)
                        <> " characters at most.",
                      ),
                    ])
                  _ -> field.Valid
                })
                |> field.view(attrs: []),
              field.new(
                ptimer.field_to_id(ptimer.Step(step.id, step.Description)),
                {
                  textbox.textbox(
                    step.description |> option.unwrap(""),
                    case model.move_op {
                      Idle ->
                        textbox.Enabled(fn(description) {
                          UpdateSteps(update_step(
                            timer.steps,
                            step.Step(
                              ..step,
                              description: case description {
                                "" -> None
                                str -> Some(str)
                              },
                            ),
                          ))
                          |> msg
                        })
                      _ -> textbox.Disabled
                    },
                    textbox.MultiLine(Some(3)),
                    _,
                  )
                },
              )
                |> field.label([element.text("Description")])
                |> field.view(attrs: []),
              field.new(ptimer.field_to_id(ptimer.Step(step.id, step.Sound)), {
                selectbox.selectbox(
                  step.sound,
                  [
                    selectbox.Option(id: "none", label: "---", value: None),
                    ..list.map(timer.assets, fn(asset) {
                      selectbox.Option(
                        id: int.to_string(asset.id),
                        label: asset.name,
                        value: Some(asset.id),
                      )
                    })
                  ],
                  case model.move_op {
                    Idle ->
                      selectbox.Enabled(fn(sound) {
                        update_step(timer.steps, step.Step(..step, sound:))
                        |> UpdateSteps
                        |> msg
                      })
                    _ -> selectbox.Disabled
                  },
                  _,
                  [],
                )
              })
                |> field.label([element.text("Sound")])
                |> field.note([
                  element.text("Sound asset to play when the step starts."),
                ])
                |> field.view(attrs: [class("action-field")]),
              html.div([class(scoped("action"))], [
                field.new(
                  ptimer.field_to_id(ptimer.Step(step.id, step.ActionType)),
                  {
                    selectbox.selectbox(
                      step.action,
                      [
                        selectbox.Option(
                          id: "user_action",
                          label: "UserAction",
                          value: step.UserAction,
                        ),
                        selectbox.Option(id: "timer", label: "Timer", value: case
                          step.action
                        {
                          step.Timer(_) -> step.action

                          _ -> step.Timer(3)
                        }),
                      ],
                      case model.move_op {
                        Idle ->
                          selectbox.Enabled(fn(option) {
                            UpdateSteps(update_step(
                              timer.steps,
                              step.Step(..step, action: option),
                            ))
                            |> msg
                          })
                        _ -> selectbox.Disabled
                      },
                      _,
                      [],
                    )
                  },
                )
                  |> field.label([element.text("Type")])
                  |> field.note(case step.action {
                    step.UserAction -> [
                      element.text(
                        "The step displays a button, which completes the step on press.",
                      ),
                    ]

                    step.Timer(_) -> [
                      element.text(
                        "The step completes when a specified duration elapsed.",
                      ),
                    ]
                  })
                  |> field.view(attrs: [class(scoped("action-field"))]),
                case step.action {
                  step.Timer(duration) ->
                    field.new(
                      ptimer.field_to_id(ptimer.Step(
                        step.id,
                        step.TimerDuration,
                      )),
                      {
                        int_input.view(
                          duration,
                          case model.move_op {
                            Idle ->
                              int_input.Enabled(fn(n) {
                                UpdateSteps(update_step(
                                  timer.steps,
                                  step.Step(
                                    ..step,
                                    action: step.Timer(int.clamp(
                                      n,
                                      min: 1,
                                      max: 60 * 60 * 24,
                                    )),
                                  ),
                                ))
                                |> msg
                              })
                            _ -> int_input.Disabled
                          },
                          Some(element.text("secs.")),
                          _,
                          [],
                        )
                      },
                    )
                    |> field.label([element.text("Duration")])
                    |> field.validity(case step_err {
                      Some(step.EncodeError(
                        action: Some(step.NegativeTimerDuration),
                        ..,
                      )) ->
                        field.Invalid([
                          element.text("Timer duration must be greater than 0."),
                        ])
                      _ -> field.Valid
                    })
                    |> field.view(attrs: [class(scoped("action-field"))])

                  _ -> element.none()
                },
              ]),
              html.div([class(scoped("step-actions"))], [
                case model.move_op {
                  Idle ->
                    button.new(button.Button(
                      Internal(StartManualMove(index, step)) |> msg,
                    ))
                    |> button.size(button.Small)
                    |> button.icon(lucide.ArrowDownUp)
                    |> button.view([], [element.text("Move")])

                  ByButton(from, _) if from == index ->
                    button.new(button.Button(Internal(CancelManualMove) |> msg))
                    |> button.variant(button.Primary)
                    |> button.size(button.Small)
                    |> button.icon(lucide.Ban)
                    |> button.view([], [element.text("Cancel")])

                  _ ->
                    button.new(button.Button(NoOp |> Internal |> msg))
                    |> button.state(button.Disabled(None))
                    |> button.size(button.Small)
                    |> button.icon(lucide.ArrowDownUp)
                    |> button.view([], [element.text("Move")])
                },
                button.new(button.Button(
                  Animate(UpdateSteps(
                    timer.steps
                    |> list.filter(fn(a) { a.id != step.id }),
                  ))
                  |> Internal
                  |> msg,
                ))
                  |> button.size(button.Small)
                  |> button.state(case model.move_op {
                    Idle -> button.Enabled
                    _ -> button.Disabled(None)
                  })
                  |> button.icon(lucide.Trash2)
                  |> button.view([], [element.text("Delete")]),
              ]),
            ]),
          ]),
        ),
        ..step_views(msg, model, rest, timer, err, index + 1)
      ]
    }
  }
}

pub fn view(
  msg: fn(Msg) -> msg,
  timer: ptimer.Ptimer,
  model: Model,
  err: dict.Dict(Int, step.EncodeError),
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
          button.new(button.Button(
            UpdateSteps([step.Step(0, "", None, None, step.UserAction)])
            |> msg,
          ))
          |> button.variant(button.Primary)
          |> button.icon(lucide.ListPlus)
          |> button.view([], [element.text("Add step")]),
        ],
        attrs: [],
      )

    steps ->
      html.div(attrs, [
        html.div([class(scoped("container"))], [
          element.keyed(
            html.div([class(scoped("list"))], _),
            step_views(msg, model, steps, timer, err, 0),
          ),
        ]),
      ])
  }
}

type StoryModel {
  StoryModel(
    timer: ptimer.Ptimer,
    model: Model,
    encoded: Result(ptimer.Encoded, ptimer.EncodeError),
  )
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
        let timer = ptimer.Ptimer(..model.timer, steps:)

        #(StoryModel(timer, m, ptimer.encode(timer)), e)
      }

      Internal(internal_msg) -> {
        action("Internal", dynamic.from(internal_msg))

        let #(m, e) = update(model.model, msg)

        #(StoryModel(model.timer, m, ptimer.encode(model.timer)), e)
      }
    }
  }

  let steps =
    flags
    |> dynamic.field("steps", dynamic.list(step.decode))
    |> result.unwrap([])

  let _ =
    lustre.application(
      fn(_) {
        let timer =
          ptimer.Ptimer(
            metadata: metadata.Metadata("1.0", "Sample Story", None, "en-US"),
            steps:,
            assets: [],
          )
        #(
          StoryModel(timer, Model(move_op: Idle), ptimer.encode(timer)),
          effect.none(),
        )
      },
      story_update,
      fn(model) {
        view(
          function.identity,
          model.timer,
          model.model,
          model.encoded
            |> result.map_error(fn(err) { err.steps })
            |> result.unwrap_error(dict.new()),
          [],
        )
      },
    )
    |> lustre.start(selector, Nil)

  Nil
}
