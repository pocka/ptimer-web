// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre
import lustre/element

pub fn main() {
  let app = lustre.element(element.text("Hello, World!"))
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
