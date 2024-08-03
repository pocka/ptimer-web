// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lucide
import lustre/attribute.{class}
import lustre/element
import lustre/element/html

// VIEW

@external(javascript, "@/ui/menu.ffi.ts", "className")
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
  html.nav([class(scoped("menu")), ..attrs], children)
}
