// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dynamic
import lucide
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element, text}
import lustre/element/html
import storybook
import ui/button

// VIEW

@external(javascript, "@/ui/placeholder.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn view(
  title title: List(Element(msg)),
  description description: List(Element(msg)),
  actions actions: List(Element(msg)),
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  html.div([class(scoped("container")), ..attrs], [
    html.p([class(scoped("title"))], title),
    html.p([], description),
    html.div([class(scoped("actions"))], actions),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _action <- storybook.story(args, ctx)

  let title = case flags |> dynamic.field("title", dynamic.string) {
    Ok(str) -> [text(str)]
    _ -> [text("Title")]
  }

  let description = case flags |> dynamic.field("description", dynamic.string) {
    Ok(str) -> [text(str)]
    _ -> [text("Description text.")]
  }

  let _ =
    lustre.simple(fn(_) { Nil }, fn(_, _) { Nil }, fn(_) {
      view(
        title,
        description,
        actions: [
          button.new(button.Button(Nil))
            |> button.variant(button.Primary)
            |> button.icon(lucide.FolderOpen)
            |> button.view([], [text("Open")]),
          button.new(button.Button(Nil))
            |> button.icon(lucide.ClipboardList)
            |> button.view([], [text("Paste")]),
        ],
        attrs: [],
      )
    })
    |> lustre.start(selector, Nil)

  Nil
}
