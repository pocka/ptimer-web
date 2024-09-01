// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import ptimer
import ptimer/step

// MODEL

type StepState {
  WaitingForUserAction

  TimerTicking(remaining_ms: Int, duration: Int)
}

type Scene {
  Initializing
  Title
  Step(step: step.Step, state: StepState, rest: List(step.Step))
  Completed
}

pub opaque type Model {
  Model(timer: ptimer.Ptimer, scene: Scene)
}

pub fn init(timer: ptimer.Ptimer) -> #(Model, Effect(Msg)) {
  #(Model(timer:, scene: Initializing), schedule_title())
}

// UPDATE

pub opaque type Internal {
  Next
  Tick(delta: Int)
}

pub type Msg {
  Internal(Internal)
}

fn init_step_state(step: step.Step) -> StepState {
  case step.action {
    step.UserAction -> WaitingForUserAction
    step.Timer(duration) -> TimerTicking(duration * 1000, duration)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model {
    Internal(Next), Model(scene: Initializing, ..) -> #(
      Model(..model, scene: Title),
      effect.none(),
    )

    Internal(Next), Model(scene: Title, timer:) ->
      case timer.steps {
        [] -> #(Model(..model, scene: Completed), effect.none())

        [step, ..rest] -> #(
          Model(..model, scene: Step(step, init_step_state(step), rest)),
          case step.action {
            step.UserAction -> effect.none()

            step.Timer(_) -> schedule_tick()
          },
        )
      }

    Internal(Next), Model(scene: Step(rest: [next, ..rest], ..), ..) -> #(
      Model(..model, scene: Step(next, init_step_state(next), rest)),
      case next.action {
        step.UserAction -> effect.none()

        step.Timer(_) -> schedule_tick()
      },
    )

    Internal(Next), Model(scene: Step(rest: [], ..), ..) -> #(
      Model(..model, scene: Completed),
      effect.none(),
    )

    Internal(Next), Model(scene: Completed, ..) -> #(
      Model(..model, scene: Title),
      effect.none(),
    )

    Internal(Tick(delta)),
      Model(
        scene: Step(state: TimerTicking(remaining_ms:, duration:), step:, rest:),
        ..,
      )
    ->
      case remaining_ms - delta {
        x if x <= 0 -> update(model, Internal(Next))

        x -> #(
          Model(
            ..model,
            scene: Step(state: TimerTicking(x, duration), step:, rest:),
          ),
          schedule_tick(),
        )
      }

    _, _ -> #(model, effect.none())
  }
}

// EFFECT

@external(javascript, "@/player/core/player.ffi.ts", "raf")
fn raf(callback: fn() -> Nil) -> Nil

fn schedule_title() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    use <- raf()

    dispatch(Internal(Next))
  })
}

@external(javascript, "@/player/core/player.ffi.ts", "tick")
fn tick(interval: Int, callback: fn(Int) -> Nil) -> Nil

fn schedule_tick() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use delta <- tick(500)

    dispatch(Internal(Tick(delta)))
  })
}

// VIEW

@external(javascript, "@/player/core/player.ffi.ts", "className")
fn scoped(x: String) -> String

fn scene_view(
  is_active: Bool,
  attrs: List(attribute.Attribute(Msg)),
  children: List(Element(Msg)),
) -> Element(Msg) {
  html.div(
    [
      case is_active {
        False -> class(scoped("inactive"))
        True -> class(scoped("active"))
      },
      class(scoped("view")),
      ..attrs
    ],
    children,
  )
}

fn title_view(timer: ptimer.Ptimer, is_active: Bool) -> Element(Msg) {
  scene_view(is_active, [], [
    html.button(
      [
        class(scoped("start")),
        attribute.disabled(!is_active),
        event.on_click(Internal(Next)),
      ],
      [html.span([class(scoped("start-text"))], [text("Start")])],
    ),
    html.div([class(scoped("metadata"))], [
      html.p([class(scoped("title"))], [text(timer.metadata.title)]),
      case timer.metadata.description {
        Some(description) ->
          html.p([class(scoped("description"))], [text(description)])
        None -> element.none()
      },
    ]),
  ])
}

fn completed_view(is_active: Bool) -> Element(Msg) {
  scene_view(is_active, [], [
    html.p([class(scoped("completed-title"))], [text("Completed.")]),
    html.button(
      [
        class(scoped("back")),
        attribute.disabled(!is_active),
        event.on_click(Internal(Next)),
      ],
      [html.span([class(scoped("back-text"))], [text("Back")])],
    ),
  ])
}

fn step_view(step: step.Step, state: Option(StepState)) -> Element(Msg) {
  scene_view(
    case state {
      Some(_) -> True
      _ -> False
    },
    [class(scoped("step-view"))],
    [
      element.keyed(html.div([], _), {
        case step.action, state {
          _, Some(WaitingForUserAction) -> [
            #(
              "interaction",
              html.button(
                [
                  class(scoped("step-action")),
                  attribute.disabled(state == None),
                  event.on_click(Internal(Next)),
                ],
                [html.span([], [text("Next")])],
              ),
            ),
          ]

          step.UserAction, _ -> [
            #(
              "interaction",
              html.button(
                [class(scoped("step-action")), attribute.disabled(True)],
                [html.span([], [text("Next")])],
              ),
            ),
          ]

          _, Some(TimerTicking(remaining_ms:, ..)) -> [
            #(
              "timer",
              html.p([class(scoped("step-action"))], [
                html.span([], [
                  text(
                    "Remaining "
                    <> int.to_string(remaining_ms / 1000)
                    <> " seconds",
                  ),
                ]),
              ]),
            ),
          ]

          step.Timer(_), _ -> [
            #(
              "timer",
              html.p([class(scoped("step-action"))], [
                html.span([], [text("Remaining 0 seconds")]),
              ]),
            ),
          ]
        }
      }),
      html.p([class(scoped("step-title"))], [text(step.title)]),
    ],
  )
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.div(
      [
        class(scoped("bg-container")),
        attribute.attribute("aria-hidden", "true"),
      ],
      [
        html.p([class(scoped("title-shadow"))], [
          text(model.timer.metadata.title),
        ]),
      ],
    ),
    title_view(model.timer, model.scene == Title),
    element.keyed(element.fragment, {
      use step <- list.map(model.timer.steps)

      #(
        int.to_string(step.id),
        step_view(step, case model.scene {
          Step(x, state, _next) if x.id == step.id -> Some(state)
          _ -> None
        }),
      )
    }),
    completed_view(model.scene == Completed),
  ])
}
