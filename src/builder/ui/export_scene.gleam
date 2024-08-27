// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/log
import builder/lucide
import builder/ptimer
import builder/ptimer/asset
import builder/ptimer/metadata
import builder/ptimer/object_url
import builder/ptimer/step
import builder/storybook
import builder/ui/button
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

// MODEL

type CompileJob {
  Idle
  Compiling(data: ptimer.Encoded)
  Compiled(data: ptimer.Encoded, url: object_url.ObjectUrl)
  FailedToCompile(data: ptimer.Encoded, reason: ptimer.CompileError)
}

pub opaque type Model {
  Model(
    data: Option(Result(ptimer.Encoded, ptimer.EncodeError)),
    job: CompileJob,
  )
}

pub fn get_encode_error(model: Model) -> Option(ptimer.EncodeError) {
  case model {
    Model(data: Some(Error(err)), ..) -> Some(err)
    _ -> None
  }
}

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(Model(data: None, job: Idle), effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  GotCompileResult(Result(object_url.ObjectUrl, ptimer.CompileError))
  NoOp
}

pub type ExternalMsg {
  Log(log.Action, log.Severity)
}

pub type Msg {
  Encode(timer: ptimer.Ptimer)
  Compile(engine: ptimer.Engine)
  JumpTo(field: ptimer.Field)
  Internal(InternalMsg)
  External(ExternalMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model {
    Encode(timer), _ -> #(
      Model(..model, data: Some(ptimer.encode(timer))),
      effect.none(),
    )

    Compile(_), Model(job: Compiling(_), ..) -> #(model, effect.none())

    Compile(engine), Model(data: Some(Ok(data)), job: job) -> #(
      Model(..model, job: Compiling(data)),
      effect.batch([
        compile(engine, data),
        case job {
          Compiled(_, prev_url) -> revoke_compiled_url(prev_url)
          _ -> effect.none()
        },
      ]),
    )

    Internal(GotCompileResult(Ok(url))), Model(job: Compiling(data), ..) -> #(
      Model(..model, job: Compiled(data, url)),
      send_msg(Log(log.CompileSuccess(data), log.Info)),
    )

    Internal(GotCompileResult(Error(err))), Model(job: Compiling(data), ..) -> #(
      Model(..model, job: FailedToCompile(data, err)),
      send_msg(Log(log.CompileFailure(data, err), log.Danger)),
    )

    _, _ -> #(model, effect.none())
  }
}

// EFFECT

fn compile(engine: ptimer.Engine, data: ptimer.Encoded) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- ptimer.compile(engine, data)

    dispatch(Internal(GotCompileResult(result)))
  })
}

fn revoke_compiled_url(url: object_url.ObjectUrl) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    object_url.revoke(url)

    dispatch(
      External(Log(
        log.InvalidateDownloadUrl(object_url.to_string(url)),
        log.Debug,
      )),
    )
  })
}

fn send_msg(msg: ExternalMsg) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(External(msg)) })
}

// VIEW

@external(javascript, "@/builder/ui/export_scene.ffi.ts", "className")
fn scoped(x: String) -> String

fn input_error(
  text: String,
  field: Option(ptimer.Field),
) -> element.Element(Msg) {
  html.li([class(scoped("input-error"))], [
    lucide.icon(lucide.OctagonX, [class(scoped("input-error-icon"))]),
    html.span([class(scoped("input-error-text"))], [element.text(text)]),
    field
      |> option.map(fn(field) {
        button.new(button.Button(JumpTo(field)))
        |> button.size(button.Small)
        |> button.view([class(scoped("input-error-jump"))], [
          element.text("Jump"),
        ])
      })
      |> option.unwrap(element.none()),
  ])
}

fn metadata_errors(
  elements: List(element.Element(Msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(Msg)) {
  case err.metadata {
    Some(err) -> [
      case err.title {
        Some(metadata.EmptyTitle) ->
          input_error(
            "Timer title can't be empty.",
            Some(ptimer.Metadata(metadata.Title)),
          )
        Some(metadata.TooLongTitle(max)) ->
          input_error(
            "Timer title must be less than or equal to "
              <> int.to_string(max)
              <> " characters.",
            Some(ptimer.Metadata(metadata.Title)),
          )
        None -> element.none()
      },
      case err.lang {
        Some(metadata.EmptyLang) ->
          input_error(
            "Timer language can't be empty.",
            Some(ptimer.Metadata(metadata.Lang)),
          )
        None -> element.none()
      },
      ..elements
    ]
    None -> elements
  }
}

fn steps_errors(
  elements: List(element.Element(Msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(Msg)) {
  err.steps
  |> dict.to_list
  |> list.fold(elements, fn(elements, pair) {
    let #(id, err) = pair

    [
      case err.title {
        Some(step.EmptyTitle) ->
          input_error(
            "Step title can't be empty.",
            Some(ptimer.Step(id, step.Title)),
          )
        Some(step.TooLongTitle(max)) ->
          input_error(
            "Step title must be less than or equal to "
              <> int.to_string(max)
              <> " characters.",
            Some(ptimer.Step(id, step.Title)),
          )
        None -> element.none()
      },
      case err.action {
        Some(step.NegativeTimerDuration) ->
          input_error(
            "Timer duration can't be negative.",
            Some(ptimer.Step(id, step.TimerDuration)),
          )
        None -> element.none()
      },
      ..elements
    ]
  })
}

fn assets_errors(
  elements: List(element.Element(Msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(Msg)) {
  err.assets
  |> dict.to_list
  |> list.fold(elements, fn(elements, pair) {
    let #(id, err) = pair

    [
      case err.name {
        Some(asset.EmptyName) ->
          input_error(
            "Asset name can't be empty.",
            Some(ptimer.Asset(id, asset.Name)),
          )
        None -> element.none()
      },
      case err.mime {
        Some(asset.EmptyMime) ->
          input_error(
            "Asset MIME type can't be empty.",
            Some(ptimer.Asset(id, asset.MIME)),
          )
        Some(asset.MimeNotIncludingSlash) ->
          input_error(
            "Asset MIME type string must include \"/\" (slash character).",
            Some(ptimer.Asset(id, asset.MIME)),
          )
        None -> element.none()
      },
      ..elements
    ]
  })
}

pub fn view(
  msg: fn(Msg) -> msg,
  engine: ptimer.Engine,
  model: Model,
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  html.div([class(scoped("container")), ..attrs], [
    html.div([class(scoped("actions"))], [
      button.new(button.Button(msg(Compile(engine))))
        |> button.variant(case model.job {
          Compiled(encoded, _) if model.data == Some(Ok(encoded)) ->
            button.Normal
          _ -> button.Primary
        })
        |> button.state(case model {
          Model(job: Compiling(_), ..) -> button.Loading(None)
          Model(data: Some(Ok(_)), ..) -> button.Enabled
          _ -> button.Disabled(None)
        })
        |> button.view([], [element.text("Compile")]),
      case model.job {
        Compiled(encoded, url) if model.data == Some(Ok(encoded)) ->
          button.new(button.Link(object_url.to_string(url), None))
          |> button.variant(button.Primary)
          |> button.view([attribute.download(ptimer.filename(encoded))], [
            element.text("Download"),
          ])
        _ ->
          button.new(button.Button(msg(Internal(NoOp))))
          |> button.state(button.Disabled(None))
          |> button.view([], [element.text("Download")])
      },
    ]),
    case model.job {
      FailedToCompile(_, err) ->
        html.p([class(scoped("compile-error"))], [
          element.text(case err {
            ptimer.UnexpectedCompileError(text) -> "Failed to compile: " <> text
            ptimer.CompileResultDecodeError(_) ->
              "Failed to communicate to Ptimer engine."
          }),
        ])
      _ -> element.none()
    },
    case model.data {
      Some(Error(err)) ->
        html.ul(
          [class(scoped("input-errors"))],
          [
            case err.timer {
              Some(ptimer.ZeroStepsError) ->
                input_error("Timer must have at least one step.", None)
              None -> element.none()
            },
          ]
            |> assets_errors(err)
            |> steps_errors(err)
            |> metadata_errors(err),
        )
        |> element.map(msg)
      _ -> element.none()
    },
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  use engine <- ptimer.new_engine()

  let timer: ptimer.Ptimer =
    flags
    |> dynamic.field("timer", ptimer.decode)
    |> result.unwrap(ptimer.empty)

  let _ =
    lustre.application(
      fn(flags) {
        let #(m1, e1) = init(flags)
        let #(m2, e2) = update(m1, Encode(timer))

        #(m2, effect.batch([e1, e2]))
      },
      fn(model, msg) {
        action("update", dynamic.from(msg))

        update(model, msg)
      },
      fn(model) {
        case engine {
          Ok(engine) -> view(function.identity, engine, model, [])
          Error(_) -> html.p([], [element.text("Failed to load engine")])
        }
      },
    )
    |> lustre.start(selector, Nil)

  Nil
}
