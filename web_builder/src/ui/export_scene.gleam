// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dict
import gleam/dynamic
import gleam/function
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
import ptimer
import ptimer/asset
import ptimer/metadata
import ptimer/step
import storybook
import ui/button

// MODEL

type CompileJob {
  Idle
  Compiling(data: ptimer.Encoded)
  Compiled(data: ptimer.Encoded, url: String)
  FailedToCompile(data: ptimer.Encoded, reason: ptimer.CompileError)
}

pub opaque type Model {
  Model(
    data: Option(Result(ptimer.Encoded, ptimer.EncodeError)),
    job: CompileJob,
  )
}

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(Model(data: None, job: Idle), effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  GotCompileResult(Result(String, ptimer.CompileError))
  NoOp
}

pub type Msg {
  Encode(timer: ptimer.Ptimer)
  Compile(engine: ptimer.Engine)
  Internal(InternalMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model {
    Encode(timer), _ -> #(
      Model(..model, data: Some(ptimer.encode(timer))),
      effect.none(),
    )

    Compile(_), Model(job: Compiling(_), ..) -> #(model, effect.none())

    Compile(engine), Model(data: Some(Ok(data)), ..) -> #(
      Model(..model, job: Compiling(data)),
      compile(engine, data),
    )

    Internal(GotCompileResult(Ok(url))), Model(job: Compiling(data), ..) -> #(
      Model(..model, job: Compiled(data, url)),
      effect.none(),
    )

    Internal(GotCompileResult(Error(err))), Model(job: Compiling(data), ..) -> #(
      Model(..model, job: FailedToCompile(data, err)),
      effect.none(),
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

// VIEW

@external(javascript, "@/ui/export_scene.ffi.ts", "className")
fn scoped(x: String) -> String

fn input_error(text: String) -> element.Element(msg) {
  html.li([class(scoped("input-error"))], [
    lucide.icon(lucide.OctagonX, [class(scoped("input-error-icon"))]),
    html.span([], [element.text(text)]),
  ])
}

fn metadata_errors(
  elements: List(element.Element(msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(msg)) {
  case err.metadata {
    Some(err) -> [
      case err.title {
        Some(metadata.EmptyTitle) -> input_error("Timer title can't be empty.")
        Some(metadata.TooLongTitle(max)) ->
          input_error(
            "Timer title must be less than or equal to "
            <> int.to_string(max)
            <> " characters.",
          )
        None -> element.none()
      },
      case err.lang {
        Some(metadata.EmptyLang) ->
          input_error("Timer language can't be empty.")
        None -> element.none()
      },
      ..elements
    ]
    None -> elements
  }
}

fn steps_errors(
  elements: List(element.Element(msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(msg)) {
  err.steps
  |> dict.to_list
  |> list.fold(elements, fn(elements, pair) {
    let #(_id, err) = pair

    [
      case err.title {
        Some(step.EmptyTitle) -> input_error("Step title can't be empty.")
        Some(step.TooLongTitle(max)) ->
          input_error(
            "Step title must be less than or equal to "
            <> int.to_string(max)
            <> " characters.",
          )
        None -> element.none()
      },
      case err.action {
        Some(step.NegativeTimerDuration) ->
          input_error("Timer duration can't be negative.")
        None -> element.none()
      },
      ..elements
    ]
  })
}

fn assets_errors(
  elements: List(element.Element(msg)),
  err: ptimer.EncodeError,
) -> List(element.Element(msg)) {
  err.assets
  |> dict.to_list
  |> list.fold(elements, fn(elements, pair) {
    let #(_id, err) = pair

    [
      case err.name {
        Some(asset.EmptyName) -> input_error("Asset name can't be empty.")
        None -> element.none()
      },
      case err.mime {
        Some(asset.EmptyMime) -> input_error("Asset MIME type can't be empty.")
        Some(asset.MimeNotIncludingSlash) ->
          input_error(
            "Asset MIME type string must include \"/\" (slash character).",
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
          Compiled(_, _) -> button.Normal
          _ -> button.Primary
        })
        |> button.state(case model {
          Model(job: Compiling(_), ..) -> button.Loading(None)
          Model(data: Some(Ok(_)), ..) -> button.Enabled
          _ -> button.Disabled(None)
        })
        |> button.view([], [element.text("Compile")]),
      case model.job {
        Compiled(encoded, url) ->
          button.new(button.Link(url, None))
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
                input_error("Timer must have at least one step.")
              None -> element.none()
            },
          ]
            |> assets_errors(err)
            |> steps_errors(err)
            |> metadata_errors(err),
        )
      _ -> element.none()
    },
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

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
      update,
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
