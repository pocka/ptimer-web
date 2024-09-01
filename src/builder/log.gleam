// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/platform_support/transferable_streams
import builder/tts
import datetime.{type DateTime}
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/result
import lustre
import lustre/attribute.{class}
import lustre/element.{text}
import lustre/element/html
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
  CompileSuccess(ptimer.Encoded)
  CompileFailure(ptimer.Encoded, ptimer.CompileError)
  InvalidateDownloadUrl(String)
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
  TTSLoadStart
  TTSLoaded
  TTSLoadingFailure(tts.TTSLoadError)
  TTSRequestedVoiceList
  TTSGotVoiceList(count: Int)
  TTSListVoiceFailure(tts.ListVoiceError)
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

fn action(action: Action) -> element.Element(msg) {
  case action {
    CreateNew -> text("Initialized a new timer.")
    StartLoadingEngine -> text("Loading Ptimer engine...")
    EngineLoaded -> text("Loaded Ptimer engine.")
    EngineLoadingFailure(err) ->
      text(
        "Failed to load Ptimer engine: "
        <> ptimer.engine_load_error_to_string(err),
      )
    StartParsing -> text("Parsing .ptimer file...")
    ParseSuccess -> text("Successfuly parsed .ptimer file.")
    ParseFailure(err) ->
      text(
        "Failed to parse .ptimer file: " <> ptimer.parse_error_to_string(err),
      )
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
    CompileSuccess(timer) ->
      text("Successfully compiled \"" <> ptimer.filename(timer) <> "\".")
    CompileFailure(timer, err) ->
      text(
        "Failed to compile \""
        <> ptimer.filename(timer)
        <> "\": "
        <> ptimer.compile_error_to_string(err),
      )
    InvalidateDownloadUrl(url) ->
      text("Invalidated an obsolete download URL to free resource: " <> url)
    TTSLoadStart -> text("Loading TTS engine...")
    TTSLoaded -> text("Loaded TTS engine.")
    TTSLoadingFailure(err) ->
      text("Failed to load TTS engine" <> tts.tts_load_error_to_string(err))
    TTSRequestedVoiceList -> text("Loading TTS voice list...")
    TTSGotVoiceList(count) ->
      text("Loaded TTS voice list (" <> int.to_string(count) <> " items).")
    TTSListVoiceFailure(err) ->
      text(
        "Failed to load TTS voice list: " <> tts.list_voice_error_to_string(err),
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

@external(javascript, "@/builder/log.ffi.ts", "className")
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
