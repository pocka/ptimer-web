// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/app
import lustre

pub fn main() {
  let app_instance = lustre.application(app.init, app.update, app.view)
  let assert Ok(_) = lustre.start(app_instance, "#app", Nil)

  Nil
}
