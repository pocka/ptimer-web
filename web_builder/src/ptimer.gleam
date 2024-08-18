// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/function
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Ptimer {
  Ptimer(metadata: Metadata, steps: List(Step), assets: List(Asset))
}

pub opaque type Encoded {
  Encoded(value: json.Json, src: Ptimer)
}

pub fn filename(e: Encoded) -> String {
  e.src.metadata.title <> ".ptimer"
}

pub type EncodeError {
  MetadataEncodeError(MetadataEncodeError)
  StepEncodeError(StepEncodeError, Step)
  AssetEncodeError(AssetEncodeError, Asset)
  ZeroStepsError
}

fn result_combine2(
  a: Result(a, List(error)),
  b: Result(b, List(error)),
  callback: fn(a, b) -> c,
) -> Result(c, List(error)) {
  case a, b {
    Ok(a), Ok(b) -> Ok(callback(a, b))
    _, _ ->
      [result.unwrap_error(a, []), result.unwrap_error(b, [])]
      |> list.flatten()
      |> Error()
  }
}

fn result_combine3(
  a: Result(a, List(error)),
  b: Result(b, List(error)),
  c: Result(c, List(error)),
  callback: fn(a, b, c) -> d,
) -> Result(d, List(error)) {
  case a, b, c {
    Ok(a), Ok(b), Ok(c) -> Ok(callback(a, b, c))
    _, _, _ ->
      [
        result.unwrap_error(a, []),
        result.unwrap_error(b, []),
        result.unwrap_error(c, []),
      ]
      |> list.flatten()
      |> Error()
  }
}

fn result_all_errors(
  a: List(Result(data, List(error))),
) -> Result(List(data), List(error)) {
  case result.partition(a) {
    #(data, []) -> Ok(data)
    #(_, errors) -> Error(list.flatten(errors))
  }
}

pub fn encode(timer: Ptimer) -> Result(Encoded, List(EncodeError)) {
  let metadata =
    timer.metadata
    |> encode_metadata()
    |> result.map_error(list.map(_, MetadataEncodeError))

  let steps =
    timer.steps
    |> list.map(fn(step) {
      step
      |> encode_step()
      |> result.map_error(fn(errors) {
        list.map(errors, StepEncodeError(_, step))
      })
    })
    |> result_all_errors()
    |> result.try(fn(steps) {
      case steps {
        [] -> Error([ZeroStepsError])
        list -> Ok(list)
      }
    })
    |> result.map(json.array(_, function.identity))

  let assets =
    timer.assets
    |> list.map(fn(asset) {
      asset
      |> encode_asset()
      |> result.map_error(fn(errors) {
        list.map(errors, AssetEncodeError(_, asset))
      })
    })
    |> result_all_errors()
    |> result.map(json.array(_, function.identity))

  use metadata, steps, assets <- result_combine3(metadata, steps, assets)

  json.object([#("metadata", metadata), #("steps", steps), #("assets", assets)])
  |> Encoded(timer)
}

pub fn decode(value: dynamic.Dynamic) -> Result(Ptimer, dynamic.DecodeErrors) {
  value
  |> dynamic.decode3(
    Ptimer,
    dynamic.field("metadata", decode_metadata),
    dynamic.field("steps", dynamic.list(decode_step)),
    dynamic.field("assets", dynamic.list(decode_asset)),
  )
}

pub type Metadata {
  Metadata(title: String, description: Option(String), lang: String)
}

pub fn decode_metadata(
  value: dynamic.Dynamic,
) -> Result(Metadata, dynamic.DecodeErrors) {
  value
  |> dynamic.decode3(
    Metadata,
    dynamic.field("title", dynamic.string),
    dynamic.field("description", dynamic.optional(dynamic.string)),
    dynamic.field("lang", dynamic.string),
  )
}

pub type MetadataEncodeError {
  EmptyMetadataTitle
  TooLongMetadataTitle(max: Int)
  EmptyMetadataLang
}

fn encode_metadata(
  metadata: Metadata,
) -> Result(json.Json, List(MetadataEncodeError)) {
  let title = case string.trim(metadata.title) {
    "" -> Error([EmptyMetadataTitle])
    text ->
      case string.length(text) {
        n if n > 256 -> Error([TooLongMetadataTitle(256)])
        _ -> Ok(#("title", json.string(text)))
      }
  }

  let lang = case string.trim(metadata.lang) {
    "" -> Error([EmptyMetadataLang])
    text -> Ok(#("lang", json.string(text)))
  }

  use title, lang <- result_combine2(title, lang)

  json.object([
    title,
    lang,
    #("description", json.nullable(metadata.description, json.string)),
  ])
}

pub type Step {
  Step(
    id: Int,
    title: String,
    description: Option(String),
    sound: Option(Int),
    action: StepAction,
  )
}

pub fn decode_step(value: dynamic.Dynamic) -> Result(Step, dynamic.DecodeErrors) {
  value
  |> dynamic.decode5(
    Step,
    dynamic.field("id", dynamic.int),
    dynamic.field("title", dynamic.string),
    dynamic.field("description", dynamic.optional(dynamic.string)),
    dynamic.field("sound", dynamic.optional(dynamic.int)),
    dynamic.decode1(
      fn(duration_seconds) {
        case duration_seconds {
          option.Some(n) -> Timer(n)
          option.None -> UserAction
        }
      },
      dynamic.field("duration_seconds", dynamic.optional(dynamic.int)),
    ),
  )
}

pub type StepEncodeError {
  EmptyStepTitle
  TooLongStepTitle(max: Int)
  NegativeTimerDuration
}

fn encode_step(step: Step) -> Result(json.Json, List(StepEncodeError)) {
  let title = case string.trim(step.title) {
    "" -> Error([EmptyStepTitle])
    text ->
      case string.length(text) {
        n if n > 128 -> Error([TooLongStepTitle(128)])
        _ -> Ok(#("title", json.string(text)))
      }
  }

  let action = case step.action {
    UserAction -> Ok(#("duration_seconds", json.null()))
    Timer(duration) if duration < 0 -> Error([NegativeTimerDuration])
    Timer(duration) -> Ok(#("duration_seconds", json.int(duration)))
  }

  use title, action <- result_combine2(title, action)

  json.object([
    title,
    action,
    #("id", json.int(step.id)),
    #("description", json.nullable(step.description, json.string)),
    #("sound", json.nullable(step.sound, json.int)),
  ])
}

pub type StepAction {
  /// Step completes when a user perform an action (mostly pressing a button)
  UserAction

  /// Step completes when the given time duration passed.
  Timer(duration: Int)
}

pub type Asset {
  Asset(
    id: Int,
    name: String,
    mime: String,
    notice: Option(String),
    url: String,
  )
}

pub type AssetEncodeError {
  EmptyAssetName
  EmptyAssetMime
  AssetMimeNotIncludingSlash
}

fn encode_asset(asset: Asset) -> Result(json.Json, List(AssetEncodeError)) {
  let name = case string.trim(asset.name) {
    "" -> Error([EmptyAssetName])
    text -> Ok(#("name", json.string(text)))
  }

  let mime = case string.trim(asset.mime) {
    "" -> Error([EmptyAssetMime])
    text ->
      case string.contains(text, contain: "/") {
        True -> Ok(#("mime", json.string(text)))
        False -> Error([AssetMimeNotIncludingSlash])
      }
  }

  use name, mime <- result_combine2(name, mime)

  json.object([
    name,
    mime,
    #("id", json.int(asset.id)),
    #("notice", json.nullable(asset.notice, json.string)),
    #("url", json.string(asset.url)),
  ])
}

@external(javascript, "@/ptimer.ffi.ts", "assetFromFile")
fn asset_from_file(id: Int, file: dynamic.Dynamic) -> dynamic.Dynamic

pub fn create_asset(
  id: Int,
  file: dynamic.Dynamic,
) -> Result(Asset, dynamic.DecodeErrors) {
  asset_from_file(id, file)
  |> decode_asset
}

@external(javascript, "@/ptimer.ffi.ts", "revokeObjectURL")
fn revoke_object_url(url: String) -> Nil

pub fn release_asset(asset: Asset) -> Nil {
  revoke_object_url(asset.url)
}

pub fn decode_asset(
  value: dynamic.Dynamic,
) -> Result(Asset, dynamic.DecodeErrors) {
  value
  |> dynamic.decode5(
    Asset,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("mime", dynamic.string),
    dynamic.field("notice", dynamic.optional(dynamic.string)),
    dynamic.field("url", dynamic.string),
  )
}

pub type EngineLoadError {
  RuntimeError(String)
  EngineDecodeError(dynamic.DecodeErrors)
}

fn decode_result(
  value: dynamic.Dynamic,
  ok: dynamic.Decoder(payload),
  err: dynamic.Decoder(error),
) -> Result(Result(payload, error), dynamic.DecodeErrors) {
  value
  |> dynamic.any([
    dynamic.decode1(Error, dynamic.field("error", err)),
    dynamic.decode1(Ok, dynamic.field("value", ok)),
  ])
}

pub opaque type Engine {
  Engine(ref: dynamic.Dynamic)
}

fn decode_load_engine_payload(
  value: dynamic.Dynamic,
) -> Result(Engine, EngineLoadError) {
  value
  |> decode_result(
    dynamic.decode1(fn(v) { Engine(v) }, dynamic.dynamic),
    dynamic.decode1(fn(details) { RuntimeError(details) }, dynamic.string),
  )
  |> result.map_error(EngineDecodeError)
  |> result.flatten
}

@external(javascript, "@/ptimer.ffi.ts", "newEngine")
fn load_engine(on_result: fn(dynamic.Dynamic) -> Nil) -> Nil

pub fn new_engine(on_created: fn(Result(Engine, EngineLoadError)) -> Nil) -> Nil {
  use value <- load_engine()

  value
  |> decode_load_engine_payload
  |> on_created
}

pub type ParseError {
  /// File is not valid SQLite3 file.
  InvalidSQLite3File

  /// File is valid SQLite3 file, but data it holds does not conform ptimer schema.
  SchemaViolation

  UnexpectedError(String)
  IllegalErrorType
  ParseResultDecodeError(dynamic.DecodeErrors)
}

fn decode_parse_error(
  value: dynamic.Dynamic,
) -> Result(ParseError, dynamic.DecodeErrors) {
  value
  |> dynamic.any([
    dynamic.decode1(UnexpectedError, dynamic.string),
    dynamic.decode1(
      fn(t) {
        case t {
          "invalid_sqlite3_file" -> InvalidSQLite3File
          "schema_violation" -> SchemaViolation
          _ -> IllegalErrorType
        }
      },
      dynamic.field("type", dynamic.string),
    ),
  ])
}

fn decode_parse_result(value: dynamic.Dynamic) -> Result(Ptimer, ParseError) {
  value
  |> decode_result(decode, decode_parse_error)
  |> result.map_error(ParseResultDecodeError)
  |> result.flatten
}

@external(javascript, "@/ptimer.ffi.ts", "parse")
fn parse_internal(
  engine: dynamic.Dynamic,
  file: dynamic.Dynamic,
  on_result: fn(dynamic.Dynamic) -> Nil,
) -> Nil

pub fn parse(
  engine: Engine,
  file: dynamic.Dynamic,
  on_result: fn(Result(Ptimer, ParseError)) -> Nil,
) -> Nil {
  use result <- parse_internal(engine.ref, file)

  result
  |> decode_parse_result
  |> on_result
}

pub type CompileError {
  UnexpectedCompileError(String)
  CompileResultDecodeError(dynamic.DecodeErrors)
}

fn decode_compile_error(
  value: dynamic.Dynamic,
) -> Result(CompileError, dynamic.DecodeErrors) {
  value
  |> dynamic.string
  |> result.map(UnexpectedCompileError)
}

fn decode_compile_result(value: dynamic.Dynamic) -> Result(String, CompileError) {
  value
  |> decode_result(dynamic.string, decode_compile_error)
  |> result.map_error(CompileResultDecodeError)
  |> result.flatten
}

@external(javascript, "@/ptimer.ffi.ts", "compile")
fn compile_internal(
  engine: dynamic.Dynamic,
  timer: dynamic.Dynamic,
  on_result: fn(dynamic.Dynamic) -> Nil,
) -> Nil

pub fn compile(
  engine: Engine,
  timer: Encoded,
  on_result: fn(Result(String, CompileError)) -> Nil,
) -> Nil {
  use result <- compile_internal(engine.ref, dynamic.from(timer.value))

  result
  |> decode_compile_result
  |> on_result
}

pub fn release(ptimer: Ptimer) -> Nil {
  ptimer.assets |> list.fold(Nil, fn(_, asset) { release_asset(asset) })
}

pub const empty: Ptimer = Ptimer(
  Metadata(title: "", description: None, lang: "en-US"),
  [],
  [],
)
