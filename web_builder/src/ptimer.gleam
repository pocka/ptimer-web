// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import ptimer/asset
import ptimer/metadata
import ptimer/object_url
import ptimer/step

pub type Ptimer {
  Ptimer(
    metadata: metadata.Metadata,
    steps: List(step.Step),
    assets: List(asset.Asset),
  )
}

pub type Field {
  Metadata(field: metadata.Field)
  Step(id: Int, field: step.Field)
  Asset(id: Int, field: asset.Field)
}

pub fn field_to_id(field: Field) -> String {
  case field {
    Metadata(field) ->
      "metadata_"
      <> {
        case field {
          metadata.Title -> "title"
          metadata.Description -> "description"
          metadata.Lang -> "lang"
        }
      }
    Step(id, field) ->
      "step_"
      <> int.to_string(id)
      <> "_"
      <> {
        case field {
          step.Title -> "title"
          step.Description -> "description"
          step.Sound -> "sound"
          step.ActionType -> "action_type"
          step.TimerDuration -> "timer_duration"
        }
      }
    Asset(id, field) ->
      "asset_"
      <> int.to_string(id)
      <> "_"
      <> {
        case field {
          asset.Name -> "name"
          asset.MIME -> "mime"
          asset.Notice -> "notice"
        }
      }
  }
}

pub opaque type Encoded {
  Encoded(value: json.Json, src: Ptimer)
}

pub fn filename(e: Encoded) -> String {
  e.src.metadata.title <> ".ptimer"
}

pub type TimerStructureError {
  ZeroStepsError
}

pub type EncodeError {
  EncodeError(
    metadata: Option(metadata.EncodeError),
    steps: Dict(Int, step.EncodeError),
    assets: Dict(Int, asset.EncodeError),
    timer: Option(TimerStructureError),
  )
}

fn result_all_errors(
  a: List(Result(data, error)),
) -> Result(List(data), List(error)) {
  case result.partition(a) {
    #(data, []) -> Ok(data |> list.reverse())
    #(_, errors) -> Error(errors)
  }
}

pub fn encode(timer: Ptimer) -> Result(Encoded, EncodeError) {
  let metadata =
    timer.metadata
    |> metadata.encode()
    |> result.map_error(Some)

  let steps =
    timer.steps
    |> list.map(fn(step) {
      step
      |> step.encode()
      |> result.map_error(fn(err) { #(step.id, err) })
    })
    |> result_all_errors()
    |> result.map(json.array(_, function.identity))
    |> result.map_error(dict.from_list)

  let assets =
    timer.assets
    |> list.map(fn(asset) {
      asset
      |> asset.encode()
      |> result.map_error(fn(err) { #(asset.id, err) })
    })
    |> result_all_errors()
    |> result.map(json.array(_, function.identity))
    |> result.map_error(dict.from_list)

  case metadata, steps, assets, list.length(timer.steps) > 0 {
    Ok(metadata), Ok(steps), Ok(assets), True ->
      json.object([
        #("metadata", metadata),
        #("steps", steps),
        #("assets", assets),
      ])
      |> Encoded(timer)
      |> Ok
    _, _, _, non_zero_steps ->
      Error(
        EncodeError(
          metadata: metadata |> result.unwrap_error(None),
          steps: steps |> result.unwrap_error(dict.new()),
          assets: assets |> result.unwrap_error(dict.new()),
          timer: case non_zero_steps {
            True -> None
            False -> Some(ZeroStepsError)
          },
        ),
      )
  }
}

pub fn decode(value: dynamic.Dynamic) -> Result(Ptimer, dynamic.DecodeErrors) {
  value
  |> dynamic.decode3(
    Ptimer,
    dynamic.field("metadata", metadata.decode),
    dynamic.field("steps", dynamic.list(step.decode)),
    dynamic.field("assets", dynamic.list(asset.decode)),
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

pub fn compile_error_to_string(err: CompileError) -> String {
  case err {
    UnexpectedCompileError(text) -> "Unexpected compile error: " <> text
    CompileResultDecodeError(_) -> "Received unexpected message payload"
  }
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
  on_result: fn(Result(object_url.ObjectUrl, CompileError)) -> Nil,
) -> Nil {
  use result <- compile_internal(engine.ref, dynamic.from(timer.value))

  result
  |> decode_compile_result
  |> result.map(object_url.from_string)
  |> on_result
}

pub fn release(ptimer: Ptimer) -> Nil {
  ptimer.assets |> list.fold(Nil, fn(_, asset) { asset.release(asset) })
}

pub const empty: Ptimer = Ptimer(
  metadata.Metadata(title: "", description: None, lang: "en-US"),
  [],
  [],
)
