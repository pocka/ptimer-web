// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import lustre
import player/shell

pub fn main() {
  let app_instance = lustre.application(shell.init, shell.update, shell.view)
  let assert Ok(_) = lustre.start(app_instance, "#app", Nil)

  Nil
}
