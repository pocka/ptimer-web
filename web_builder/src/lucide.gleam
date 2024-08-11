// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre/attribute
import lustre/element

pub type IconType {
  ChevronDown
  ClipboardList
  FileMusic
  FolderOpen
  GripHorizontal
  ListOrdered
  Menu
  ScrollText
}

fn icon_type_to_string(icon_type: IconType) -> String {
  case icon_type {
    ChevronDown -> "chevron-down"
    ClipboardList -> "clipboard-list"
    FileMusic -> "file-music"
    FolderOpen -> "folder-open"
    GripHorizontal -> "grip-horizontal"
    ListOrdered -> "list-ordered"
    Menu -> "menu"
    ScrollText -> "scroll-text"
  }
}

pub fn icon(
  icon_type: IconType,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  element.element("lucide-" <> icon_type_to_string(icon_type), attrs, [])
}
