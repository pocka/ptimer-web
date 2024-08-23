// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/result
import ptimer/object_url

pub opaque type TTS {
  Engine(ref: dynamic.Dynamic)
}

pub type TTSLoadError {
  TTSLoadError(String)
  TTSDecodeError(dynamic.DecodeErrors)
}

pub fn tts_load_error_to_string(err: TTSLoadError) -> String {
  case err {
    TTSLoadError(str) -> str
    TTSDecodeError(_) -> "Invalid message sent from worker"
  }
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

fn decode_load_tts_result(value: dynamic.Dynamic) -> Result(TTS, TTSLoadError) {
  value
  |> decode_result(
    dynamic.decode1(Engine, dynamic.dynamic),
    dynamic.decode1(TTSLoadError, dynamic.string),
  )
  |> result.map_error(TTSDecodeError)
  |> result.flatten
}

@external(javascript, "@/tts.ffi.ts", "newTTSEngine")
fn load_tts_engine(callback: fn(dynamic.Dynamic) -> Nil) -> Nil

pub fn new_tts(on_created: fn(Result(TTS, TTSLoadError)) -> Nil) -> Nil {
  use value <- load_tts_engine()

  value
  |> decode_load_tts_result
  |> on_created
}

pub opaque type VoiceKey {
  VoiceKey(raw_key: String)
}

pub type Voice {
  Voice(key: VoiceKey, name: String, lang: String)
}

pub fn voice_id(voice: Voice) -> String {
  voice.key.raw_key
}

fn decode_voice(value: dynamic.Dynamic) -> Result(Voice, dynamic.DecodeErrors) {
  value
  |> dynamic.decode3(
    Voice,
    dynamic.decode1(VoiceKey, dynamic.field("key", dynamic.string)),
    dynamic.field("displayName", dynamic.string),
    dynamic.field("languageCode", dynamic.string),
  )
}

pub type ListVoiceError {
  ListVoiceError(String)
  ListVoiceDecodeError(dynamic.DecodeErrors)
}

pub fn list_voice_error_to_string(err: ListVoiceError) -> String {
  case err {
    ListVoiceError(str) -> str
    ListVoiceDecodeError(_) -> "Invalid voice list data sent from worker"
  }
}

@external(javascript, "@/tts.ffi.ts", "getPredefinedVoices")
fn list_voices_internal() -> dynamic.Dynamic

pub fn list_voices(
  _tts: TTS,
  callback: fn(Result(List(Voice), ListVoiceError)) -> Nil,
) -> Nil {
  list_voices_internal()
  |> dynamic.list(decode_voice)
  |> result.map_error(ListVoiceDecodeError)
  |> callback
}

pub type RunError {
  RunError(String)
  RunDecodeError(dynamic.DecodeErrors)
}

pub fn run_error_to_string(err: RunError) -> String {
  case err {
    RunError(str) -> str
    RunDecodeError(_) -> "Invalid inference result sent from worker"
  }
}

@external(javascript, "@/tts.ffi.ts", "run")
fn run_internal(
  tts: dynamic.Dynamic,
  text: String,
  voice_key: String,
  callback: fn(dynamic.Dynamic) -> Nil,
) -> Nil

pub fn run(
  tts: TTS,
  text: String,
  voice: Voice,
  callback: fn(Result(object_url.ObjectUrl, RunError)) -> Nil,
) -> Nil {
  use value <- run_internal(tts.ref, text, voice.key.raw_key)

  value
  |> decode_result(
    dynamic.decode1(object_url.from_string, dynamic.string),
    dynamic.decode1(RunError, dynamic.string),
  )
  |> result.map_error(RunDecodeError)
  |> result.flatten
  |> callback
}
