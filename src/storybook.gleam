// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic

pub type Context

pub type Story

pub type Args

@external(javascript, "@/storybook.ffi.ts", "render")
pub fn story(
  args: Args,
  ctx: Context,
  on_render: fn(String, dynamic.Dynamic, fn(String, dynamic.Dynamic) -> Nil) ->
    Nil,
) -> Story
