// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/option.{type Option, None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html

@external(javascript, "@/simple/app/standard_page.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn render(
  title title: String,
  description description: Option(String),
  actions actions: List(Element(msg)),
) -> Element(msg) {
  html.div([class(scoped("layout"))], [
    html.p([class(scoped("title"))], [text(title)]),
    case description {
      Some(str) -> html.p([class(scoped("description"))], [text(str)])
      None -> html.div([class(scoped("description"))], [])
    },
    case actions {
      [] -> element.none()
      _ -> html.div([class(scoped("actions"))], actions)
    },
  ])
}
