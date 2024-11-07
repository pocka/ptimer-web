// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import castle/core
import datetime.{type DateTime}
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import ptimer
import storybook

// MODEL

type LazyModule(model, msg) {
  LazyModule(
    init: fn(ptimer.Engine) -> #(model, Effect(msg)),
    update: fn(model, msg) -> #(model, Effect(msg)),
    view: fn(model) -> Element(msg),
  )
}

type Loadable(data, error) {
  Loading
  LoadFailed(error)
  Loaded(data)
}

type Boot {
  Booting(
    core: Loadable(LazyModule(core.Model, core.Msg), String),
    engine: Loadable(ptimer.Engine, ptimer.EngineLoadError),
  )
  Booted(
    model: core.Model,
    core: LazyModule(core.Model, core.Msg),
    engine: ptimer.Engine,
  )
}

type LogKind {
  StartedLoadingCore
  StartedLoadingEngine
  FailedToLoadCore(String)
  FailedToLoadEngine(ptimer.EngineLoadError)
  LoadedCore
  LoadedEngine
}

type LogEntry {
  LogEntry(id: Int, ts: DateTime, kind: LogKind)
}

pub opaque type Model {
  Model(boot: Boot, logs: List(LogEntry))
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(boot: Booting(core: Loading, engine: Loading), logs: []),
    effect.batch([
      log(StartedLoadingCore),
      log(StartedLoadingEngine),
      load_core(),
      load_engine(),
    ]),
  )
}

// UPDATE

pub opaque type Msg {
  GotCore(Result(LazyModule(core.Model, core.Msg), String))
  GotEngine(Result(ptimer.Engine, ptimer.EngineLoadError))
  CoreMsg(core.Msg)
  RetryBoot
  Log(kind: LogKind)
}

fn init_core(x: #(Model, Effect(Msg))) -> #(Model, Effect(Msg)) {
  case x {
    #(Model(boot: Booting(core: Loaded(core), engine: Loaded(engine)), ..), e1) -> {
      let #(m, e2) = core.init(engine)

      #(
        Model(..x.0, boot: Booted(model: m, core:, engine:)),
        effect.batch([e1, effect.map(e2, CoreMsg)]),
      )
    }

    _ -> x
  }
}

fn get_largest_log_id(logs: List(LogEntry), max: Int) -> Int {
  case logs {
    [] -> max
    [head, ..tail] if head.id > max -> get_largest_log_id(tail, head.id)
    [_, ..tail] -> get_largest_log_id(tail, max)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model {
    GotEngine(Ok(engine)), Model(boot: Booting(core:, ..), ..) ->
      #(
        Model(..model, boot: Booting(core:, engine: Loaded(engine))),
        log(LoadedEngine),
      )
      |> init_core

    GotEngine(Error(err)), Model(boot: Booting(core:, ..), ..) -> #(
      Model(..model, boot: Booting(core:, engine: LoadFailed(err))),
      log(FailedToLoadEngine(err)),
    )

    GotCore(Ok(module)), Model(boot: Booting(engine:, ..), ..) ->
      #(
        Model(..model, boot: Booting(engine:, core: Loaded(module))),
        log(LoadedCore),
      )
      |> init_core

    GotCore(Error(err)), Model(boot: Booting(engine:, ..), ..) -> #(
      Model(..model, boot: Booting(engine:, core: LoadFailed(err))),
      log(FailedToLoadCore(err)),
    )

    CoreMsg(sub_msg), Model(boot: Booted(model: sub_model, core:, engine:), ..) -> {
      let #(m, e) = core.update(sub_model, sub_msg)

      #(
        Model(..model, boot: Booted(model: m, core:, engine:)),
        effect.map(e, CoreMsg),
      )
    }

    RetryBoot, _ -> {
      let #(core, engine) = case model.boot {
        Booting(core:, engine:) -> #(core, engine)
        Booted(core:, engine:, ..) -> #(Loaded(core), Loaded(engine))
      }

      let #(core, core_effect) = case core {
        LoadFailed(_) -> #(Loading, load_core())
        _ -> #(core, effect.none())
      }

      let #(engine, engine_effect) = case engine {
        LoadFailed(_) -> #(Loading, load_engine())
        _ -> #(engine, effect.none())
      }

      #(
        Model(..model, boot: Booting(core:, engine:)),
        effect.batch([core_effect, engine_effect]),
      )
      |> init_core
    }

    Log(kind), Model(logs:, ..) -> {
      #(
        Model(
          ..model,
          logs: [
            LogEntry(
              id: get_largest_log_id(logs, -1) + 1,
              ts: datetime.now(),
              kind:,
            ),
            ..logs
          ],
        ),
        effect.none(),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

// EFFECT

@external(javascript, "@/castle/shell.ffi.ts", "loadCore")
fn ffi_load_core(
  on_error: fn(String) -> Nil,
  on_load: fn(
    fn(ptimer.Engine) -> #(core.Model, Effect(core.Msg)),
    fn(core.Model, core.Msg) -> #(core.Model, Effect(core.Msg)),
    fn(core.Model) -> Element(core.Msg),
  ) ->
    Nil,
) -> Nil

fn load_core() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    // TODO: Handle error
    use init, update, view <- ffi_load_core(fn(err) {
      dispatch(GotCore(Error(err)))
    })

    dispatch(GotCore(Ok(LazyModule(init:, update:, view:))))
  })
}

fn load_engine() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    use engine <- ptimer.new_engine()

    dispatch(GotEngine(engine))
  })
}

fn log(kind: LogKind) -> Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(Log(kind)) })
}

// VIEW

@external(javascript, "@/castle/shell.ffi.ts", "className")
fn scoped(x: String) -> String

fn log_kind_to_element(kind: LogKind) -> Element(msg) {
  case kind {
    StartedLoadingEngine -> text("Started loading Ptimer engine...")
    StartedLoadingCore -> text("Started loading the application...")
    LoadedEngine -> text("Successfully loaded Ptimer engine")
    LoadedCore -> text("Successfully loaded the application.")
    FailedToLoadCore(err) ->
      element.fragment([
        text("Failed to load the application: "),
        html.span([class(scoped("error-message"))], [text(err)]),
      ])
    FailedToLoadEngine(err) ->
      element.fragment([
        text("Failed to load Ptimer engine: "),
        html.span([class(scoped("error-message"))], [
          text(ptimer.engine_load_error_to_string(err)),
        ]),
      ])
  }
}

fn loading_status() -> Element(msg) {
  html.div([class(scoped("status"))], [
    html.p(
      [class(scoped("loading"))],
      "Loading..."
        |> string.split(on: "")
        |> list.index_map(fn(char, i) {
          html.span([attribute.style([#("--_index", int.to_string(i))])], [
            text(char),
          ])
        }),
    ),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  element.keyed(html.div([], _), [
    #("core", case model.boot {
      Booted(model:, core:, ..) -> core.view(model) |> element.map(CoreMsg)

      _ -> html.noscript([], [])
    }),
    #(
      "boot",
      html.div(
        [
          class(scoped("boot")),
          ..{
            case model.boot {
              Booted(..) -> [
                class(scoped("loaded")),
                attribute.attribute("aria-hidden", "true"),
              ]
              _ -> []
            }
          }
        ],
        [
          {
            let #(core, engine) = case model.boot {
              Booting(core:, engine:) -> #(core, engine)
              Booted(core:, engine:, ..) -> #(Loaded(core), Loaded(engine))
            }

            case core, engine {
              Loading, _ -> loading_status()

              _, Loading -> loading_status()

              Loaded(_), Loaded(_) -> loading_status()

              _, _ ->
                html.div([class(scoped("status"))], [
                  html.p([], [text("Loading failed")]),
                  html.button(
                    [
                      attribute.type_("button"),
                      class(scoped("retry")),
                      event.on_click(RetryBoot),
                    ],
                    [text("Retry")],
                  ),
                ])
            }
          },
          element.keyed(html.ol([class(scoped("logs"))], _), {
            use entry <- list.map(model.logs)

            #(
              int.to_string(entry.id),
              html.li([class(scoped("log-entry"))], [
                html.span([class(scoped("log-ts"))], [
                  text(datetime.locale_string(entry.ts)),
                ]),
                html.span([], [log_kind_to_element(entry.kind)]),
              ]),
            )
          }),
        ],
      ),
    ),
  ])
}

// STORYBOOK

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  use engine <- ptimer.new_engine()

  let story_update = fn(model: Model, msg: Msg) {
    action("update", dynamic.from(msg))

    update(model, msg)
  }

  let core = case flags |> dynamic.field("core", dynamic.string) {
    Ok("loaded") ->
      Loaded(LazyModule(init: core.init, update: core.update, view: core.view))
    Ok("failed") -> LoadFailed("Test Error")
    _ -> Loading
  }

  let engine = case engine, flags |> dynamic.field("engine", dynamic.string) {
    Error(err), _ -> LoadFailed(err)

    Ok(engine), Ok("loaded") -> Loaded(engine)

    _, Ok("failed") -> LoadFailed(ptimer.RuntimeError("Test Error"))

    _, _ -> Loading
  }

  let app = case flags |> dynamic.field("full", dynamic.bool) {
    Ok(True) -> lustre.application(init, story_update, view)

    _ ->
      lustre.application(
        fn(_) {
          #(
            Model(boot: Booting(core, engine), logs: [
              LogEntry(id: 5, ts: datetime.now(), kind: StartedLoadingEngine),
              LogEntry(
                id: 4,
                ts: datetime.now(),
                kind: FailedToLoadEngine(ptimer.RuntimeError("Sample Error")),
              ),
              LogEntry(id: 3, ts: datetime.now(), kind: StartedLoadingCore),
              LogEntry(
                id: 2,
                ts: datetime.now(),
                kind: FailedToLoadCore("Sample Error"),
              ),
              LogEntry(id: 1, ts: datetime.now(), kind: StartedLoadingCore),
              LogEntry(id: 0, ts: datetime.now(), kind: StartedLoadingEngine),
            ]),
            effect.none(),
          )
          |> init_core
        },
        fn(model, msg) {
          action("update", dynamic.from(msg))

          update(model, msg)
        },
        view,
      )
  }

  let _ =
    app
    |> lustre.start(selector, Nil)

  Nil
}
