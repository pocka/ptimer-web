// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import datetime
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import ptimer
import ptimer/step
import simple/app/log
import simple/app/standard_page
import storybook

// MODEL

type PlayerState {
  TitleScene
  PlayingStep(
    head: step.Step,
    tail: List(step.Step),
    previous: Option(step.Step),
  )
  CompletedScene
}

type InitializedState {
  Idle
  OpeningFile(file: dynamic.Dynamic)
  FileOpened(timer: ptimer.Ptimer, player: PlayerState)
  FailedToOpenFile(file: dynamic.Dynamic, reason: ptimer.ParseError)
}

type State {
  NotInitializedYet
  Initializing
  Initialized(engine: ptimer.Engine, state: InitializedState)
  FailedToInitialize(reason: ptimer.EngineLoadError)
}

type Model {
  Model(logs: List(log.Log), state: State, countdown_seconds: Option(Int))
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  Model(logs: [], state: NotInitializedYet, countdown_seconds: None)
  |> update(Initialize)
}

// UPDATE

@external(javascript, "@/simple/app/main.ffi.ts", "getFilename")
fn get_filename(file: dynamic.Dynamic) -> String

type Msg {
  Initialize
  GotInitializeResult(Result(ptimer.Engine, ptimer.EngineLoadError))
  OpenFile(file: dynamic.Dynamic)
  GotOpenFileResult(Result(ptimer.Ptimer, ptimer.ParseError))
  ClearFile
  StartTimer
  EndTimer
  NextStep
  StartCountdown
  UpdateCountdownSeconds(Int)
  PlayAsset
}

fn update_chain(
  prev: #(Model, effect.Effect(Msg)),
  msg: Msg,
) -> #(Model, effect.Effect(Msg)) {
  let next = update(prev.0, msg)

  #(next.0, effect.batch([prev.1, next.1]))
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model.state {
    Initialize, _ -> #(
      Model(
        ..model,
        logs: [log.new(log.System(log.StartedInitialization)), ..model.logs],
        state: Initializing,
      ),
      initialize(),
    )

    GotInitializeResult(Ok(engine)), _ -> #(
      Model(
        ..model,
        logs: [log.new(log.System(log.CompletedInitialization)), ..model.logs],
        state: Initialized(engine, Idle),
      ),
      effect.none(),
    )

    GotInitializeResult(Error(err)), _ -> #(
      Model(
        ..model,
        logs: [log.new(log.System(log.FailedToInitialize(err))), ..model.logs],
        state: FailedToInitialize(err),
      ),
      effect.none(),
    )

    OpenFile(file:), Initialized(engine:, ..) -> #(
      Model(
        ..model,
        logs: [
          log.new(log.User(log.SelectedFile(get_filename(file)))),
          ..model.logs
        ],
        state: Initialized(engine:, state: OpeningFile(file:)),
      ),
      open_file(engine, file),
    )

    GotOpenFileResult(Ok(timer)), Initialized(engine:, state: OpeningFile(file))
    -> #(
      Model(
        ..model,
        logs: [
          log.new(log.System(log.OpenedFile(get_filename(file)))),
          ..model.logs
        ],
        state: Initialized(engine:, state: FileOpened(timer, TitleScene)),
      ),
      effect.none(),
    )

    GotOpenFileResult(Error(reason)),
      Initialized(engine:, state: OpeningFile(file:))
    -> #(
      Model(
        ..model,
        logs: [
          log.new(log.System(log.FailedToOpenFile(get_filename(file), reason))),
          ..model.logs
        ],
        state: Initialized(engine:, state: FailedToOpenFile(file:, reason:)),
      ),
      effect.none(),
    )

    ClearFile, Initialized(engine:, ..) -> #(
      Model(
        ..model,
        logs: [log.new(log.User(log.ClearedFile)), ..model.logs],
        state: Initialized(engine:, state: Idle),
      ),
      effect.none(),
    )

    StartTimer,
      Initialized(engine:, state: FileOpened(timer:, player: TitleScene))
    ->
      Model(
        ..model,
        logs: [
          log.new(log.User(log.StartedTimer(timer.metadata.title))),
          ..model.logs
        ],
        state: Initialized(
          engine:,
          state: FileOpened(timer:, player: case timer.steps {
            [] -> CompletedScene
            [head, ..tail] -> PlayingStep(head, tail, None)
          }),
        ),
      )
      |> update(PlayAsset)
      |> update_chain(StartCountdown)

    NextStep,
      Initialized(
        engine:,
        state: FileOpened(timer:, player: PlayingStep(current, rest, _)),
      )
    ->
      Model(
        ..model,
        logs: [
          log.new(case current.action {
            step.Timer(_) -> log.System(log.CompletedTimerStep(current.title))
            step.UserAction ->
              log.User(log.CompletedUserActionStep(current.title))
          }),
          ..model.logs
        ],
        state: Initialized(
          engine:,
          state: FileOpened(timer:, player: case rest {
            [] -> CompletedScene
            [head, ..tail] -> PlayingStep(head, tail, Some(current))
          }),
        ),
      )
      |> update(PlayAsset)
      |> update_chain(StartCountdown)

    EndTimer, Initialized(engine:, state: FileOpened(timer:, ..)) -> #(
      Model(
        ..model,
        logs: [
          log.new(log.User(log.EndedTimer(timer.metadata.title))),
          ..model.logs
        ],
        state: Initialized(engine:, state: Idle),
      ),
      effect.none(),
    )

    StartCountdown,
      Initialized(
        state: FileOpened(
          player: PlayingStep(
            step.Step(
              action: step.Timer(duration),
              ..,
            ),
            ..,
          ),
          ..,
        ),
        ..,
      )
    -> #(Model(..model, countdown_seconds: Some(duration)), countdown(duration))

    UpdateCountdownSeconds(x), _ -> #(
      Model(..model, countdown_seconds: Some(x)),
      effect.none(),
    )

    PlayAsset,
      Initialized(
        state: FileOpened(
          player: PlayingStep(step, _, prev),
          ..,
        ),
        ..,
      )
    -> #(
      model,
      effect.batch([
        case step.sound {
          Some(id) -> play_asset(id)
          None -> effect.none()
        },
        case prev {
          Some(step.Step(sound: Some(id), ..)) -> stop_asset(id)
          _ -> effect.none()
        },
      ]),
    )

    _, _ -> #(model, effect.none())
  }
}

// EFFECT

fn initialize() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- ptimer.new_engine()

    dispatch(GotInitializeResult(result))
  })
}

fn open_file(engine: ptimer.Engine, file: dynamic.Dynamic) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- ptimer.parse(engine, file)

    dispatch(GotOpenFileResult(result))
  })
}

@external(javascript, "@/simple/app/main.ffi.ts", "interval")
fn set_interval(ms: Int, cb: fn() -> Bool) -> Nil

fn countdown(duration: Int) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    let start = datetime.now() |> datetime.timestamp

    use <- set_interval(100)

    let now = datetime.now() |> datetime.timestamp
    let elapsed = { now - start } / 1000

    case elapsed >= duration {
      True -> {
        dispatch(NextStep)
        False
      }
      False -> {
        dispatch(UpdateCountdownSeconds({ duration - elapsed } |> int.max(0)))
        True
      }
    }
  })
}

fn asset_id(id: Int) -> String {
  "__audio_" <> int.to_string(id)
}

@external(javascript, "@/simple/app/main.ffi.ts", "playAudioElement")
fn play_audio_element(id: String) -> Nil

@external(javascript, "@/simple/app/main.ffi.ts", "stopAudioElement")
fn stop_audio_element(id: String) -> Nil

fn play_asset(id: Int) -> effect.Effect(Msg) {
  effect.from(fn(_) { play_audio_element(asset_id(id)) })
}

fn stop_asset(id: Int) -> effect.Effect(Msg) {
  effect.from(fn(_) { stop_audio_element(asset_id(id)) })
}

// VIEW

fn seconds(seconds x: Int) -> element.Element(msg) {
  element.text(case x {
    x if x < 0 -> "00:00"

    x -> {
      let hours = x / 60 |> int.to_string |> string.pad_left(2, "0")
      let minutes = x % 60 |> int.to_string |> string.pad_left(2, "0")

      hours <> ":" <> minutes
    }
  })
}

@external(javascript, "@/simple/app/main.ffi.ts", "className")
fn scoped(x: String) -> String

@external(javascript, "@/builder/ui/button.ffi.ts", "getFirstFile")
fn get_first_file(ev: dynamic.Dynamic) -> dynamic.Dynamic

fn state_view(model: Model) -> element.Element(Msg) {
  case model.state {
    Initialized(_, Idle) ->
      html.div([class(scoped("idle"))], [
        html.p([], [element.text("Select a timer file.")]),
        html.input([
          class(scoped("visually-hidden")),
          attribute.type_("file"),
          attribute.accept([".ptimer"]),
          attribute.id("timer_file"),
          event.on("input", fn(ev) {
            get_first_file(ev)
            |> dynamic.optional(dynamic.dynamic)
            |> result.map(fn(file) {
              case file {
                Some(file) -> Ok(OpenFile(file))
                _ -> Error([])
              }
            })
            |> result.flatten
          }),
        ]),
        html.label([class(scoped("button")), attribute.for("timer_file")], [
          element.text("Open file picker"),
        ]),
      ])

    Initialized(_, OpeningFile(_)) ->
      html.div([class(scoped("loading"))], [element.text("Opening file...")])

    Initialized(_, FailedToOpenFile(file, reason)) ->
      standard_page.render(
        title: "Failed to open a timer file.",
        description: Some(ptimer.parse_error_to_string(reason)),
        actions: [
          html.button(
            [
              class(scoped("outline-button")),
              attribute.type_("button"),
              event.on_click(ClearFile),
            ],
            [element.text("Cancel")],
          ),
          html.button(
            [
              class(scoped("button")),
              attribute.type_("button"),
              event.on_click(OpenFile(file)),
            ],
            [element.text("Retry")],
          ),
        ],
      )

    Initialized(_, FileOpened(timer, TitleScene)) ->
      standard_page.render(
        title: timer.metadata.title,
        description: timer.metadata.description,
        actions: [
          html.button(
            [
              class(scoped("button")),
              attribute.type_("button"),
              event.on_click(StartTimer),
            ],
            [element.text("Start")],
          ),
        ],
      )

    Initialized(_, FileOpened(timer, CompletedScene)) ->
      standard_page.render(
        title: "Completed \"" <> timer.metadata.title <> "\"",
        description: None,
        actions: [
          html.button(
            [
              class(scoped("button")),
              attribute.type_("button"),
              event.on_click(EndTimer),
            ],
            [element.text("Done")],
          ),
        ],
      )

    Initialized(_, FileOpened(_, PlayingStep(step, rest, _))) ->
      standard_page.render(
        title: step.title,
        description: step.description,
        actions: [
          case rest {
            [] -> element.none()
            [next, ..] ->
              html.span([class(scoped("next-step"))], [
                element.text("Next > "),
                element.text(next.title),
              ])
          },
          case step.action {
            step.UserAction ->
              html.button(
                [
                  class(scoped("button")),
                  attribute.type_("button"),
                  event.on_click(NextStep),
                ],
                [element.text("Done")],
              )
            step.Timer(duration) ->
              html.span([class(scoped("countdown"))], [
                seconds(model.countdown_seconds |> option.unwrap(duration)),
              ])
          },
        ],
      )

    FailedToInitialize(reason:) ->
      standard_page.render(
        title: "Failed to initialize application",
        description: Some(ptimer.engine_load_error_to_string(reason)),
        actions: [
          html.button(
            [
              class(scoped("button")),
              attribute.type_("button"),
              event.on_click(Initialize),
            ],
            [element.text("Retry")],
          ),
        ],
      )

    _ -> html.p([class(scoped("loading"))], [element.text("Initializing...")])
  }
}

fn audio_in_use(model: Model) -> #(Option(Int), Option(Int), Option(Int)) {
  let next = case model.state {
    Initialized(_, FileOpened(ptimer.Ptimer(steps: [step, ..], ..), TitleScene)) ->
      Some(step)

    Initialized(_, FileOpened(_, PlayingStep(_, [head, ..], _))) -> Some(head)

    _ -> None
  }

  let #(prev, current) = case model.state {
    Initialized(_, FileOpened(_, PlayingStep(current, _, prev))) -> #(
      prev |> option.map(fn(step) { step.sound }) |> option.flatten,
      current.sound,
    )

    _ -> #(None, None)
  }

  #(
    prev,
    current,
    next |> option.map(fn(step) { step.sound }) |> option.flatten,
  )
}

fn audio_view(model: Model) -> element.Element(Msg) {
  let #(prev, current, next) = audio_in_use(model)

  element.keyed(element.fragment, case model.state {
    Initialized(_, FileOpened(timer, ..)) -> {
      let asset_in_use =
        timer.assets
        |> list.filter(fn(asset) {
          case asset.id {
            x if Some(x) == prev -> True
            x if Some(x) == current -> True
            x if Some(x) == next -> True
            _ -> False
          }
        })

      use asset <- list.map(asset_in_use)

      #(
        int.to_string(asset.id),
        html.audio(
          [
            attribute.id(asset_id(asset.id)),
            attribute.src(asset.url),
            attribute.attribute("preload", "auto"),
          ],
          [],
        ),
      )
    }

    _ -> []
  })
}

fn view(model: Model) -> element.Element(Msg) {
  html.div([class(scoped("layout"))], [
    html.div([class(scoped("main"))], [state_view(model)]),
    element.keyed(html.ul([class(scoped("logs"))], _), {
      use item <- list.map(model.logs)

      #(int.to_string(item.timestamp), log.view(item))
    }),
    audio_view(model),
  ])
}

// STORYBOOK

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

  use engine_result <- ptimer.new_engine()

  let state =
    flags
    |> dynamic.field("state", dynamic.string)
    |> option.from_result

  let app = case state, engine_result {
    Some(str), Ok(engine) -> {
      let resolved_state = case str {
        "NotInitializedYet" -> NotInitializedYet
        "Initializing" -> Initializing
        "FailedToInitialize" ->
          FailedToInitialize(ptimer.RuntimeError("Sample Error"))
        "Idle" -> Initialized(engine, Idle)
        _ -> NotInitializedYet
      }

      lustre.application(
        fn(_) {
          #(
            Model(logs: [], state: resolved_state, countdown_seconds: None),
            effect.none(),
          )
        },
        update,
        view,
      )
    }
    _, _ -> lustre.application(init, update, view)
  }

  let _ = lustre.start(app, selector, Nil)

  Nil
}

// MAIN

pub fn main() {
  let app_instance = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app_instance, "#app", Nil)

  Nil
}
