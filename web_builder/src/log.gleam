// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import datetime.{type DateTime}
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/result
import lustre
import lustre/attribute.{class}
import lustre/element.{text}
import lustre/element/html
import platform_support/transferable_streams
import ptimer
import storybook

// MODEL

pub type Severity {
  Debug
  Info
  Warning
  Danger
}

pub type Action {
  CreateNew
  StartLoadingEngine
  EngineLoaded
  EngineLoadingFailure(ptimer.EngineLoadError)
  StartParsing
  ParseSuccess
  ParseFailure(ptimer.ParseError)
  DetectedTransferableStreamSupported
  DetectedTransferableStreamNotSupported
  TransferableStreamDetectionFailure(
    transferable_streams.SupportStatusDetectionError,
  )
}

pub opaque type Log {
  Log(id: Int, action: Action, logged_at: DateTime, severity: Severity)
}

// UPDATE

pub fn append(logs: List(Log), action: Action, severity: Severity) -> List(Log) {
  case logs {
    [latest, ..] -> [
      Log(latest.id + 1, action, datetime.now(), severity),
      ..logs
    ]

    [] -> [Log(0, action, datetime.now(), severity)]
  }
}

// VIEW

fn parse_error_to_string(err: ptimer.ParseError) -> String {
  case err {
    ptimer.InvalidSQLite3File -> "The file is not a valid .ptimer file"
    ptimer.SchemaViolation ->
      "The file is not a valid .ptimer file (SchemaViolation)"
    ptimer.UnexpectedError(details) -> details
    ptimer.IllegalErrorType -> "Unexpected error (IllegalErrorType)"
    ptimer.ParseResultDecodeError(_) -> "Received unexpected message payload"
  }
}

fn engine_load_error_to_string(err: ptimer.EngineLoadError) -> String {
  case err {
    ptimer.RuntimeError(details) -> details
    ptimer.EngineDecodeError(_) -> "Received unexpected message payload"
  }
}

fn action(action: Action) -> element.Element(msg) {
  case action {
    CreateNew -> text("Initialized a new timer.")
    StartLoadingEngine -> text("Loading Ptimer engine...")
    EngineLoaded -> text("Loaded Ptimer engine.")
    EngineLoadingFailure(err) ->
      text("Failed to load Ptimer engine: " <> engine_load_error_to_string(err))
    StartParsing -> text("Parsing .ptimer file...")
    ParseSuccess -> text("Successfuly parsed .ptimer file.")
    ParseFailure(err) ->
      text("Failed to parse .ptimer file: " <> parse_error_to_string(err))
    DetectedTransferableStreamSupported ->
      text("Detected Transferable Streams support.")
    DetectedTransferableStreamNotSupported ->
      text(
        "This browser does not implement Transferable Streams. Disabled open file feature.",
      )
    TransferableStreamDetectionFailure(err) ->
      text(
        "Failed to detect Transferable Streams platform support: "
        <> transferable_streams.detection_error_to_string(err),
      )
  }
}

fn severity(s: Severity) -> element.Element(msg) {
  let #(module_class, label) = case s {
    Debug -> #("log-debug", "DEBUG")
    Info -> #("log-info", "INFO")
    Warning -> #("log-warn", "WARN")
    Danger -> #("log-danger", "DANGER")
  }

  html.span([class(scoped(module_class))], [text(label)])
}

@external(javascript, "@/log.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  logs: List(Log),
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  html.div([class(scoped("container"))], [
    element.keyed(html.ul([class(scoped("logs")), ..attrs], _), {
      use log <- list.map(logs)

      #(
        log.id |> int.to_string,
        html.li([class(scoped("log"))], [
          html.span([class(scoped("log-severity"))], [severity(log.severity)]),
          html.span([class(scoped("log-datetime"))], [
            log.logged_at |> datetime.locale_string |> text,
          ]),
          html.span([class(scoped("log-message"))], [action(log.action)]),
        ]),
      )
    }),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

  let is_empty =
    flags
    |> dynamic.field("empty", dynamic.bool)
    |> result.unwrap(False)

  let _ =
    lustre.element(
      view(
        case is_empty {
          True -> []
          False -> [
            Log(0, CreateNew, datetime.now(), Info),
            Log(1, StartLoadingEngine, datetime.now(), Debug),
            Log(
              2,
              DetectedTransferableStreamNotSupported,
              datetime.now(),
              Warning,
            ),
            Log(
              3,
              EngineLoadingFailure(ptimer.RuntimeError("Unexpected Error")),
              datetime.now(),
              Danger,
            ),
            Log(4, CreateNew, datetime.now(), Info),
            Log(5, CreateNew, datetime.now(), Info),
            Log(6, CreateNew, datetime.now(), Info),
            Log(7, CreateNew, datetime.now(), Info),
            Log(8, CreateNew, datetime.now(), Info),
            Log(9, CreateNew, datetime.now(), Info),
            Log(10, CreateNew, datetime.now(), Info),
          ]
        },
        [],
      ),
    )
    |> lustre.start(selector, Nil)

  Nil
}
