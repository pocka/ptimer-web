// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

pub type DateTime

@external(javascript, "@/datetime.ffi.ts", "now")
pub fn now() -> DateTime

@external(javascript, "@/datetime.ffi.ts", "to_timestamp")
pub fn timestamp(datetime: DateTime) -> Int

@external(javascript, "@/datetime.ffi.ts", "to_locale_string")
pub fn locale_string(datetime: DateTime) -> String
