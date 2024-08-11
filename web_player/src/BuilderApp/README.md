<!--
SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Why not "builder/"?

Because Elm compiler arrogantly forces files and direcotries to have PascalCase name.

Changing the `builder/` to `Builder/` alters resulting app's URL structure, hence the separated directory.
This is not the case if macOS/Windows used a sane filesystem—case sensitive one.
