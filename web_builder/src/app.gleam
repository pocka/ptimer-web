// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/list
import gleam/option.{type Option, None, Some}
import log
import lucide
import lustre
import lustre/attribute.{class}
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import platform_support/transferable_streams
import ptimer
import storybook
import ui/button
import ui/menu
import ui/metadata_editor
import ui/steps_editor

// MODEL

type Engine {
  Loading
  Loaded(ptimer.Engine)
  FailedToLoad(ptimer.EngineLoadError)
}

type ParsingJob {
  Idle
  Parsing
  FailedToParse(ptimer.ParseError)
}

type Scene {
  MetadataEditor
  StepsEditor
  AssetsEditor
  LogsViewer
}

pub opaque type Model {
  Model(
    engine: Engine,
    timer: Option(ptimer.Ptimer),
    parsing: ParsingJob,
    logs: List(log.Log),
    scene: Scene,
    transferable_streams: transferable_streams.SupportStatus,
  )
}

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  let transferable_streams_support = transferable_streams.support_status()

  #(
    Model(
      engine: Loading,
      timer: case transferable_streams_support {
        transferable_streams.NotSupported -> Some(ptimer.empty)

        _ -> None
      },
      parsing: Idle,
      logs: []
        |> log.append(log.StartLoadingEngine, log.Debug)
        |> fn(logs) {
          case transferable_streams_support {
            transferable_streams.Supported ->
              log.append(
                logs,
                log.DetectedTransferableStreamSupported,
                log.Debug,
              )

            transferable_streams.NotSupported ->
              logs
              |> log.append(
                log.DetectedTransferableStreamNotSupported,
                log.Warning,
              )
              |> log.append(log.CreateNew, log.Debug)

            transferable_streams.FailedToDetect(err) ->
              log.append(
                logs,
                log.TransferableStreamDetectionFailure(err),
                log.Danger,
              )
          }
        },
      scene: MetadataEditor,
      transferable_streams: transferable_streams_support,
    ),
    prepare_engine(),
  )
}

// UPDATE

pub opaque type Msg {
  LoadEngine
  ReceiveEngineLoadResult(Result(ptimer.Engine, ptimer.EngineLoadError))
  Parse(file: dynamic.Dynamic)
  ReceiveParseResult(Result(ptimer.Ptimer, ptimer.ParseError))
  NavigateTo(Scene)
  OpenFilePicker
  CreateNewTimer
  UpdateTimer(ptimer.Ptimer)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model {
    LoadEngine, _ -> #(
      Model(
        ..model,
        engine: Loading,
        logs: model.logs |> log.append(log.StartLoadingEngine, log.Debug),
      ),
      prepare_engine(),
    )

    ReceiveEngineLoadResult(Ok(engine)), _ -> #(
      Model(
        ..model,
        engine: Loaded(engine),
        parsing: Idle,
        logs: model.logs |> log.append(log.EngineLoaded, log.Info),
      ),
      effect.none(),
    )

    ReceiveEngineLoadResult(Error(err)), _ -> #(
      Model(
        ..model,
        engine: FailedToLoad(err),
        logs: model.logs
          |> log.append(log.EngineLoadingFailure(err), log.Danger),
      ),
      effect.none(),
    )

    Parse(file), Model(engine: Loaded(engine), parsing: parsing, ..)
      if parsing != Parsing
    -> #(
      Model(
        ..model,
        parsing: Parsing,
        logs: model.logs |> log.append(log.StartParsing, log.Debug),
      ),
      parse(engine, file),
    )

    ReceiveParseResult(Ok(timer)), Model(timer: prev, parsing: Parsing, ..) -> #(
      Model(
        ..model,
        scene: MetadataEditor,
        timer: Some(timer),
        parsing: Idle,
        logs: model.logs |> log.append(log.ParseSuccess, log.Info),
      ),
      case prev {
        Some(file) -> release(file)

        _ -> effect.none()
      },
    )

    ReceiveParseResult(Error(err)), Model(parsing: Parsing, logs: logs, ..) -> #(
      Model(
        ..model,
        parsing: FailedToParse(err),
        logs: logs |> log.append(log.ParseFailure(err), log.Danger),
      ),
      effect.none(),
    )

    NavigateTo(scene), _ if model.scene != scene -> #(
      Model(..model, scene: scene),
      effect.none(),
    )

    OpenFilePicker, _ -> #(model, select_file())

    CreateNewTimer, Model(timer: None, ..) -> #(
      Model(
        ..model,
        scene: MetadataEditor,
        timer: Some(ptimer.empty),
        logs: model.logs |> log.append(log.CreateNew, log.Debug),
      ),
      effect.none(),
    )

    UpdateTimer(timer), _ -> #(
      Model(..model, timer: Some(timer)),
      effect.none(),
    )

    _, _ -> #(model, effect.none())
  }
}

// EFFECT

fn prepare_engine() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use engine <- ptimer.new_engine()

    dispatch(ReceiveEngineLoadResult(engine))
  })
}

@external(javascript, "@/app.ffi.ts", "openFilePicker")
fn open_file_picker(
  accept: String,
  on_select: fn(dynamic.Dynamic) -> Nil,
) -> Nil

fn select_file() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use file <- open_file_picker(".ptimer")

    dispatch(Parse(file))
  })
}

fn parse(engine: ptimer.Engine, file: dynamic.Dynamic) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- ptimer.parse(engine, file)

    dispatch(ReceiveParseResult(result))
  })
}

fn release(file: ptimer.Ptimer) -> effect.Effect(Msg) {
  effect.from(fn(_) { ptimer.release(file) })
}

// VIEW

@external(javascript, "@/app.ffi.ts", "className")
fn scoped(x: String) -> String

fn with_file(
  model: Model,
  callback: fn(ptimer.Engine, ptimer.Ptimer) -> element.Element(Msg),
) -> element.Element(Msg) {
  case model.engine, model.timer {
    Loaded(engine), Some(timer) -> callback(engine, timer)

    Loaded(_), None ->
      html.div([class(scoped("placeholder"))], [
        html.p([class(scoped("placeholder-title"))], [
          element.text("Ptimer editor"),
        ]),
        html.div([class(scoped("welcome-actions"))], [
          button.button(button.Primary, button.Enabled(OpenFilePicker), [], [
            element.text("Select file"),
          ]),
          button.button(button.Normal, button.Enabled(CreateNewTimer), [], [
            element.text("Create new timer"),
          ]),
        ]),
      ])

    Loading, _ -> html.p([], [element.text("Loading Ptimer engine...")])

    FailedToLoad(_), _ ->
      html.div([], [
        html.p([], [element.text("Failed to load Ptimer engine")]),
        html.button([event.on_click(LoadEngine)], [element.text("Retry")]),
      ])
  }
}

pub fn view(model: Model) -> element.Element(Msg) {
  html.div([class(scoped("layout"))], [
    menu.menu([class(scoped("menu"))], {
      [
        menu.item(
          lucide.ClipboardList,
          [
            menu.active(model.scene == MetadataEditor),
            event.on_click(NavigateTo(MetadataEditor)),
          ],
          [element.text("Metadata")],
        ),
        menu.item(
          lucide.ListOrdered,
          [
            menu.active(model.scene == StepsEditor),
            event.on_click(NavigateTo(StepsEditor)),
          ],
          [element.text("Steps")],
        ),
        menu.item(
          lucide.FileMusic,
          [
            menu.active(model.scene == AssetsEditor),
            event.on_click(NavigateTo(AssetsEditor)),
          ],
          [element.text("Assets")],
        ),
        case model.transferable_streams {
          transferable_streams.NotSupported -> element.none()

          _ ->
            menu.item(lucide.FolderOpen, [event.on_click(OpenFilePicker)], [
              element.text("Open"),
            ])
        },
        menu.item(
          lucide.ScrollText,
          [
            menu.active(model.scene == LogsViewer),
            event.on_click(NavigateTo(LogsViewer)),
          ],
          [element.text("Logs")],
        ),
      ]
    }),
    html.div([class(scoped("body"))], [
      case model.scene {
        MetadataEditor -> {
          use _, file <- with_file(model)

          metadata_editor.view(file, UpdateTimer, [])
        }

        StepsEditor -> {
          use _, file <- with_file(model)

          steps_editor.view(file, UpdateTimer, [])
        }

        AssetsEditor -> {
          use _, file <- with_file(model)

          html.ol(
            [],
            file.assets
              |> list.map(fn(asset) { html.li([], [element.text(asset.name)]) }),
          )
        }

        LogsViewer ->
          html.div([class(scoped("logs-container"))], [
            log.view(model.logs, [class(scoped("logs"))]),
          ])
      },
    ]),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, _flags, _action <- storybook.story(args, ctx)

  let _ =
    lustre.application(init, update, view)
    |> lustre.start(selector, Nil)

  Nil
}
