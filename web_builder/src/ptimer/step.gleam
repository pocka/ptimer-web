// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

// TYPE

pub type Step {
  Step(
    id: Int,
    title: String,
    description: Option(String),
    sound: Option(Int),
    action: StepAction,
  )
}

pub type StepAction {
  /// Step completes when a user perform an action (mostly pressing a button)
  UserAction

  /// Step completes when the given time duration passed.
  Timer(duration: Int)
}

pub type Field {
  Title
  Description
  Sound
  ActionType
  TimerDuration
}

// DECODE

pub fn decode(value: dynamic.Dynamic) -> Result(Step, dynamic.DecodeErrors) {
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

// ENCODE

pub type TitleEncodeError {
  EmptyTitle
  TooLongTitle(max: Int)
}

pub type ActionEncodeError {
  NegativeTimerDuration
}

pub type EncodeError {
  EncodeError(
    title: Option(TitleEncodeError),
    action: Option(ActionEncodeError),
  )
}

pub fn encode(step: Step) -> Result(json.Json, EncodeError) {
  let title = case string.trim(step.title) {
    "" -> Error(Some(EmptyTitle))
    text ->
      case string.length(text) {
        n if n > 128 -> Error(Some(TooLongTitle(128)))
        _ -> Ok(#("title", json.string(text)))
      }
  }

  let action = case step.action {
    UserAction -> Ok(#("duration_seconds", json.null()))
    Timer(duration) if duration < 0 -> Error(Some(NegativeTimerDuration))
    Timer(duration) -> Ok(#("duration_seconds", json.int(duration)))
  }

  case title, action {
    Ok(title), Ok(action) ->
      Ok(
        json.object([
          title,
          action,
          #("id", json.int(step.id)),
          #("description", json.nullable(step.description, json.string)),
          #("sound", json.nullable(step.sound, json.int)),
        ]),
      )
    _, _ ->
      Error(EncodeError(
        title: title |> result.unwrap_error(None),
        action: action |> result.unwrap_error(None),
      ))
  }
}
