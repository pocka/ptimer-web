// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}

pub fn view(attrs: List(Attribute(msg))) -> Element(msg) {
  element.element("ptimer-logo", attrs, [])
}
