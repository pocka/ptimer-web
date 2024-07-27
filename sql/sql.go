// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

package sql

import (
	_ "embed"

	"database/sql"
)

//go:embed init.sql
var initSQL string

func Init(db *sql.DB) error {
	_, err := db.Exec(initSQL)

	return err
}
