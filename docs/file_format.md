<!--
SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# File Format

The timer file is a SQLite database file.

## Database schema

### `metadata` table

This table can contain exactly one record.

| Column      | Data type       | Description                       |
| ----------- | --------------- | --------------------------------- |
| title       | TEXT            | Title of the timer.               |
| description | TEXT or NULL    | Description of the timer.         |
| lang        | TEXT            | Language code for timer contents. |

### `step` table

| Column           | Data type       | Description                                                                       |
| ---------------- | --------------- | --------------------------------------------------------------------------------- |
| id               | INTEGER         |                                                                                   |
| title            | TEXT            | Title of the step. Newlines and control characters are not allowed.               |
| description      | TEXT or NULL    | Descriptive text. Control characters are not allowed.                             |
| sound            | INTEGER or NULL | `id` of an audio `asset` to play when the step starts.                            |
| duration_seconds | INTEGER or NULL | Duration of the step, in seconds.                                                 |
| index            | INTEGER         | Sorting index. Must be unique, but does not have to be a natural number sequence. |

### `asset` table

| Column | Data type    | Description                         |
| ------ | ------------ | ----------------------------------- |
| id     | INTEGER      |                                     |
| name   | TEXT         | Human-readable name of the asset.   |
| mime   | TEXT         | MIME of the asset.                  |
| data   | BLOB         | Binary data of the asset.           |
| notice | TEXT or NULL | Copyright notice text of the asset. |
