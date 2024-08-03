// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { defineConfig } from "vite";
import gleam from "vite-gleam";

export default defineConfig({
	optimizeDeps: {
		// Without this, Vite can't load WASM file
		exclude: ["@sqlite.org/sqlite-wasm"],
	},
	resolve: {
		alias: {
			"@": new URL("./src", import.meta.url).pathname,
		},
	},
	plugins: [gleam()],
});
