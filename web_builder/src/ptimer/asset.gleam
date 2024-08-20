// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

// TYPE

pub type Asset {
  Asset(
    id: Int,
    name: String,
    mime: String,
    notice: Option(String),
    url: String,
  )
}

// DECODE

pub fn decode(value: dynamic.Dynamic) -> Result(Asset, dynamic.DecodeErrors) {
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

@external(javascript, "@/ptimer/asset.ffi.ts", "fromFile")
fn from_file(id: Int, file: dynamic.Dynamic) -> dynamic.Dynamic

pub fn create(
  id: Int,
  file: dynamic.Dynamic,
) -> Result(Asset, dynamic.DecodeErrors) {
  from_file(id, file)
  |> decode
}

// ENCODE

pub type NameEncodeError {
  EmptyName
}

pub type MimeEncodeError {
  EmptyMime
  MimeNotIncludingSlash
}

pub type EncodeError {
  EncodeError(name: Option(NameEncodeError), mime: Option(MimeEncodeError))
}

pub fn encode(asset: Asset) -> Result(json.Json, EncodeError) {
  let name = case string.trim(asset.name) {
    "" -> Error(Some(EmptyName))
    text -> Ok(#("name", json.string(text)))
  }

  let mime = case string.trim(asset.mime) {
    "" -> Error(Some(EmptyMime))
    text ->
      case string.contains(text, contain: "/") {
        True -> Ok(#("mime", json.string(text)))
        False -> Error(Some(MimeNotIncludingSlash))
      }
  }

  case name, mime {
    Ok(name), Ok(mime) ->
      Ok(
        json.object([
          name,
          mime,
          #("id", json.int(asset.id)),
          #("notice", json.nullable(asset.notice, json.string)),
          #("url", json.string(asset.url)),
        ]),
      )
    _, _ ->
      Error(EncodeError(
        name: name |> result.unwrap_error(None),
        mime: mime |> result.unwrap_error(None),
      ))
  }
}

// MISC

@external(javascript, "@/ptimer/asset.ffi.ts", "revokeObjectURL")
fn revoke_object_url(url: String) -> Nil

pub fn release(asset: Asset) -> Nil {
  revoke_object_url(asset.url)
}
