// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

// TYPE

pub type Metadata {
  Metadata(title: String, description: Option(String), lang: String)
}

// DECODE

pub fn decode(value: dynamic.Dynamic) -> Result(Metadata, dynamic.DecodeErrors) {
  value
  |> dynamic.decode3(
    Metadata,
    dynamic.field("title", dynamic.string),
    dynamic.field("description", dynamic.optional(dynamic.string)),
    dynamic.field("lang", dynamic.string),
  )
}

// ENCODE

pub type TitleEncodeError {
  EmptyTitle
  TooLongTitle(max: Int)
}

pub type LangEncodeError {
  EmptyLang
}

pub type EncodeError {
  EncodeError(title: Option(TitleEncodeError), lang: Option(LangEncodeError))
}

pub fn encode(metadata: Metadata) -> Result(json.Json, EncodeError) {
  let title = case string.trim(metadata.title) {
    "" -> Error(Some(EmptyTitle))
    text ->
      case string.length(text) {
        n if n > 256 -> Error(Some(TooLongTitle(256)))
        _ -> Ok(#("title", json.string(text)))
      }
  }

  let lang = case string.trim(metadata.lang) {
    "" -> Error(Some(EmptyLang))
    text -> Ok(#("lang", json.string(text)))
  }

  case title, lang {
    Ok(title), Ok(lang) ->
      Ok(
        json.object([
          title,
          lang,
          #("description", json.nullable(metadata.description, json.string)),
        ]),
      )
    _, _ ->
      Error(EncodeError(
        title: title |> result.unwrap_error(None),
        lang: lang |> result.unwrap_error(None),
      ))
  }
}
