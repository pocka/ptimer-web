// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

pub opaque type ObjectUrl {
  ObjectUrl(String)
}

pub fn to_string(url: ObjectUrl) -> String {
  case url {
    ObjectUrl(str) -> str
  }
}

pub fn from_string(url: String) -> ObjectUrl {
  ObjectUrl(url)
}

@external(javascript, "@/ptimer/object_url.ffi.ts", "revokeObjectURL")
fn revoke_object_url(url: String) -> Nil

pub fn revoke(url: ObjectUrl) -> Nil {
  url
  |> to_string
  |> revoke_object_url
}
