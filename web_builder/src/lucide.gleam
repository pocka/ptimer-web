// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre/attribute
import lustre/element

pub type IconType {
  ArrowDownUp
  Ban
  ChevronDown
  ClipboardList
  CornerLeftDown
  Download
  FileMusic
  FilePlus
  FolderOpen
  Globe
  GripHorizontal
  ListOrdered
  ListPlus
  Menu
  OctagonX
  Play
  ScrollText
  Speech
  Square
  Trash2
}

fn icon_type_to_string(icon_type: IconType) -> String {
  case icon_type {
    ArrowDownUp -> "arrow-down-up"
    Ban -> "ban"
    ChevronDown -> "chevron-down"
    ClipboardList -> "clipboard-list"
    CornerLeftDown -> "corner-left-down"
    Download -> "download"
    FileMusic -> "file-music"
    FilePlus -> "file-plus"
    FolderOpen -> "folder-open"
    Globe -> "globe"
    GripHorizontal -> "grip-horizontal"
    ListOrdered -> "list-ordered"
    ListPlus -> "list-plus"
    Menu -> "menu"
    ScrollText -> "scroll-text"
    OctagonX -> "octagon-x"
    Play -> "play"
    Speech -> "speech"
    Square -> "square"
    Trash2 -> "trash2"
  }
}

pub fn icon(
  icon_type: IconType,
  attrs: List(attribute.Attribute(msg)),
) -> element.Element(msg) {
  element.element("lucide-" <> icon_type_to_string(icon_type), attrs, [])
}
