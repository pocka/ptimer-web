// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dict
import gleam/dynamic
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
import ui/assets_editor
import ui/button
import ui/export_scene
import ui/menu
import ui/metadata_editor
import ui/placeholder
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
  StepsEditor(steps_editor.Model)
  AssetsEditor(assets_editor.Model)
  ExportScene
  LogsViewer
}

pub opaque type Model {
  Model(
    engine: Engine,
    timer: Option(ptimer.Ptimer),
    parsing: ParsingJob,
    logs: List(log.Log),
    scene: Scene,
    export: export_scene.Model,
    transferable_streams: transferable_streams.SupportStatus,
  )
}

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  let transferable_streams_support = transferable_streams.support_status()
  let export = export_scene.init(Nil)

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
      export: export.0,
      transferable_streams: transferable_streams_support,
    ),
    effect.batch([prepare_engine(), effect.map(export.1, ExportSceneMsg)]),
  )
}

// UPDATE

pub opaque type Msg {
  LoadEngine
  ReceiveEngineLoadResult(Result(ptimer.Engine, ptimer.EngineLoadError))
  Parse(file: dynamic.Dynamic)
  ReceiveParseResult(Result(ptimer.Ptimer, ptimer.ParseError))
  NavigateTo(Scene)
  OpenStepsEditor
  StepsEditorMsg(steps_editor.Msg)
  OpenAssetsEditor
  AssetsEditorMsg(assets_editor.Msg)
  OpenFilePicker
  CreateNewTimer
  UpdateTimer(ptimer.Ptimer)
  ExportSceneMsg(export_scene.Msg)
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
      effect.batch([
        case prev {
          Some(file) -> release(file)

          _ -> effect.none()
        },
        encode_timer(timer),
      ]),
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

    OpenStepsEditor, _ -> {
      case model.scene {
        StepsEditor(_) -> #(model, effect.none())

        _ -> {
          let #(m, e) = steps_editor.init(Nil)

          #(
            Model(..model, scene: StepsEditor(m)),
            effect.map(e, StepsEditorMsg),
          )
        }
      }
    }

    StepsEditorMsg(steps_editor.UpdateSteps(steps)),
      Model(
        scene: StepsEditor(sub_model),
        timer: Some(timer),
        ..,
      )
    -> {
      let #(m, e) =
        steps_editor.update(sub_model, steps_editor.UpdateSteps(steps))

      let new_timer = ptimer.Ptimer(..timer, steps:)

      #(
        Model(..model, scene: StepsEditor(m), timer: Some(new_timer)),
        effect.batch([effect.map(e, StepsEditorMsg), encode_timer(new_timer)]),
      )
    }

    StepsEditorMsg(sub_msg), Model(scene: StepsEditor(sub_model), ..) -> {
      let #(m, e) = steps_editor.update(sub_model, sub_msg)

      #(Model(..model, scene: StepsEditor(m)), effect.map(e, StepsEditorMsg))
    }

    OpenAssetsEditor, _ -> {
      case model.scene {
        AssetsEditor(_) -> #(model, effect.none())

        _ -> {
          let #(m, e) = assets_editor.init(Nil)

          #(
            Model(..model, scene: AssetsEditor(m)),
            effect.map(e, AssetsEditorMsg),
          )
        }
      }
    }

    AssetsEditorMsg(assets_editor.Update(f)),
      Model(
        scene: AssetsEditor(sub_model),
        timer: Some(timer),
        ..,
      )
    -> {
      let #(m, e) = assets_editor.update(sub_model, assets_editor.Update(f))

      let new_timer = f(timer)

      #(
        Model(..model, scene: AssetsEditor(m), timer: Some(new_timer)),
        effect.batch([effect.map(e, AssetsEditorMsg), encode_timer(new_timer)]),
      )
    }

    AssetsEditorMsg(sub_msg), Model(scene: AssetsEditor(sub_model), ..) -> {
      let #(m, e) = assets_editor.update(sub_model, sub_msg)

      #(Model(..model, scene: AssetsEditor(m)), effect.map(e, AssetsEditorMsg))
    }

    OpenFilePicker, _ -> #(model, select_file())

    CreateNewTimer, Model(timer: None, ..) -> #(
      Model(
        ..model,
        scene: MetadataEditor,
        timer: Some(ptimer.empty),
        logs: model.logs |> log.append(log.CreateNew, log.Debug),
      ),
      encode_timer(ptimer.empty),
    )

    UpdateTimer(timer), _ -> #(
      Model(..model, timer: Some(timer)),
      encode_timer(timer),
    )

    ExportSceneMsg(export_scene.JumpTo(field)), Model(export: sub_model, ..) -> {
      let #(export_model, export_effect) =
        export_scene.update(sub_model, export_scene.JumpTo(field))

      let #(m, e) =
        update(Model(..model, export: export_model), case field {
          ptimer.Metadata(_) -> NavigateTo(MetadataEditor)
          ptimer.Step(_, _) -> OpenStepsEditor
          ptimer.Asset(_, _) -> OpenAssetsEditor
        })

      #(
        m,
        effect.batch([
          effect.map(export_effect, ExportSceneMsg),
          e,
          focus_element(ptimer.field_to_id(field)),
        ]),
      )
    }

    ExportSceneMsg(export_scene.External(export_scene.Log(action, severity))), _
    -> {
      #(
        Model(..model, logs: log.append(model.logs, action, severity)),
        effect.none(),
      )
    }

    ExportSceneMsg(sub_msg), Model(export: sub_model, ..) -> {
      let #(m, e) = export_scene.update(sub_model, sub_msg)

      #(Model(..model, export: m), effect.map(e, ExportSceneMsg))
    }

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

fn encode_timer(timer: ptimer.Ptimer) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    dispatch(ExportSceneMsg(export_scene.Encode(timer)))
  })
}

@external(javascript, "@/app.ffi.ts", "raf")
fn request_animation_frame(callback: fn() -> Nil) -> Nil

@external(javascript, "@/app.ffi.ts", "tryFocus")
fn focus(id: String) -> Nil

fn focus_element(id: String) -> effect.Effect(Msg) {
  effect.from(fn(_dispatch) {
    use <- request_animation_frame()

    focus(id)
  })
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
      placeholder.view(
        title: [element.text("Ptimer editor")],
        description: [
          element.text("This is an editor application for "),
          html.code([class(scoped("code"))], [element.text(".ptimer")]),
          element.text(" files."),
        ],
        actions: [
          button.new(button.FilePicker(Parse, [".ptimer"]))
            |> button.variant(button.Primary)
            |> button.icon(lucide.FolderOpen)
            |> button.view([], [element.text("Select file")]),
          button.new(button.Button(CreateNewTimer))
            |> button.icon(lucide.FilePlus)
            |> button.view([], [element.text("Create new timer")]),
        ],
        attrs: [],
      )

    Loading, _ -> html.p([], [element.text("Loading Ptimer engine...")])

    FailedToLoad(_), _ ->
      html.div([], [
        html.p([], [element.text("Failed to load Ptimer engine")]),
        html.button([event.on_click(LoadEngine)], [element.text("Retry")]),
      ])
  }
}

pub fn view(model: Model) -> element.Element(Msg) {
  let encode_error = export_scene.get_encode_error(model.export)

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
            menu.active(case model.scene {
              StepsEditor(_) -> True
              _ -> False
            }),
            event.on_click(OpenStepsEditor),
          ],
          [element.text("Steps")],
        ),
        menu.item(
          lucide.FileMusic,
          [
            menu.active(case model.scene {
              AssetsEditor(_) -> True
              _ -> False
            }),
            event.on_click(OpenAssetsEditor),
          ],
          [element.text("Assets")],
        ),
        menu.item(
          lucide.Download,
          [
            menu.active(model.scene == ExportScene),
            event.on_click(NavigateTo(ExportScene)),
          ],
          [element.text("Export")],
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

          metadata_editor.view(
            file,
            UpdateTimer,
            encode_error |> option.then(fn(err) { err.metadata }),
            [],
          )
        }

        StepsEditor(sub_model) -> {
          use _, file <- with_file(model)

          steps_editor.view(
            StepsEditorMsg,
            file,
            sub_model,
            encode_error
              |> option.map(fn(err) { err.steps })
              |> option.unwrap(dict.new()),
            [],
          )
        }

        AssetsEditor(sub_model) -> {
          use _, file <- with_file(model)

          assets_editor.view(
            AssetsEditorMsg,
            file,
            sub_model,
            encode_error
              |> option.map(fn(err) { err.assets })
              |> option.unwrap(dict.new()),
            [],
          )
        }

        ExportScene -> {
          use engine, _ <- with_file(model)

          export_scene.view(ExportSceneMsg, engine, model.export, [])
        }

        LogsViewer -> log.view(model.logs, [])
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
