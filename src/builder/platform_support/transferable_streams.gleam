// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import gleam/result

pub type SupportStatusDetectionError {
  DecodeError(dynamic.DecodeErrors)
  UnexpectedError(String)
}

pub fn detection_error_to_string(err: SupportStatusDetectionError) -> String {
  case err {
    DecodeError(_) -> "Application internals (FFI) retured illegal messages."
    UnexpectedError(message) -> message
  }
}

pub type SupportStatus {
  Supported
  NotSupported
  FailedToDetect(SupportStatusDetectionError)
}

@external(javascript, "@/builder/platform_support/transferable_streams.ffi.ts", "getSupportStatus")
fn get_support_status() -> dynamic.Dynamic

pub fn support_status() -> SupportStatus {
  get_support_status()
  |> dynamic.any([
    dynamic.decode1(
      FailedToDetect,
      dynamic.decode1(UnexpectedError, dynamic.field("error", dynamic.string)),
    ),
    dynamic.decode1(
      fn(supported) {
        case supported {
          True -> Supported

          False -> NotSupported
        }
      },
      dynamic.field("supported", dynamic.bool),
    ),
  ])
  |> result.map_error(DecodeError)
  |> result.map_error(FailedToDetect)
  |> result.unwrap_both()
}
