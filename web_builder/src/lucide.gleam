// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre/attribute
import lustre/element

pub type IconType {
  ChevronDown
  ClipboardList
  FileMusic
  FilePlus
  FolderOpen
  GripHorizontal
  ListOrdered
  ListPlus
  Menu
  ScrollText
  Trash2
}

fn icon_type_to_string(icon_type: IconType) -> String {
  case icon_type {
    ChevronDown -> "chevron-down"
    ClipboardList -> "clipboard-list"
    FileMusic -> "file-music"
    FilePlus -> "file-plus"
    FolderOpen -> "folder-open"
    GripHorizontal -> "grip-horizontal"
    ListOrdered -> "list-ordered"
    ListPlus -> "list-plus"
    Menu -> "menu"
    ScrollText -> "scroll-text"
    Trash2 -> "trash2"
  }
}

pub fn icon(
  icon_type: IconType,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  element.element("lucide-" <> icon_type_to_string(icon_type), attrs, [])
}
