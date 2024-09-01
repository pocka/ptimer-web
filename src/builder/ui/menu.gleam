// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/lucide
import builder/ui/logo
import gleam/dynamic
import gleam/result
import lustre
import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import storybook

// VIEW

@external(javascript, "@/builder/ui/menu.ffi.ts", "className")
fn scoped(x: String) -> String

pub fn item(
  icon: lucide.IconType,
  attrs: List(attribute.Attribute(msg)),
  children: List(element.Element(msg)),
) -> element.Element(msg) {
  html.button([class(scoped("item")), ..attrs], [
    lucide.icon(icon, [class(scoped("item-icon"))]),
    html.span([class(scoped("item-label"))], children),
  ])
}

pub fn active(is_active: Bool) -> attribute.Attribute(msg) {
  case is_active {
    True -> class(scoped("item-active"))
    False -> attribute.none()
  }
}

pub fn menu(
  attrs: List(attribute.Attribute(msg)),
  children: List(element.Element(msg)),
) -> element.Element(msg) {
  html.nav([class(scoped("menu")), ..attrs], [
    html.div([class(scoped("list"))], [
      logo.view([
        class(scoped("logo")),
        attribute.role("img"),
        attribute.attribute("aria-label", "Ptimer's logo"),
      ]),
      ..children
    ]),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, _ <- storybook.story(args, ctx)

  let has_active_item =
    flags |> dynamic.field("active", dynamic.bool) |> result.unwrap(False)

  let _ =
    lustre.element(
      menu([], [
        item(lucide.FolderOpen, [active(has_active_item)], [
          element.text("Item A"),
        ]),
        item(lucide.Menu, [], [element.text("Item B")]),
        item(lucide.FileMusic, [], [element.text("Item C")]),
      ]),
    )
    |> lustre.start(selector, Nil)

  Nil
}
