// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/option.{type Option, None}
import gleam/result

pub type Ptimer {
  Ptimer(metadata: Metadata, steps: List(Step), assets: List(Asset))
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

@external(javascript, "@/ptimer.ffi.ts", "release")
pub fn release(ptimer: Ptimer) -> Nil

pub const empty: Ptimer = Ptimer(
  Metadata(title: "", description: None, lang: "en-US"),
  [],
  [],
)
