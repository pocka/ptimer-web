// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { defineConfig } from "vite";
import gleam from "vite-gleam";
import elm from "vite-plugin-elm";

export default defineConfig({
	root: new URL("./src", import.meta.url).pathname,
	build: {
		outDir: "../dist",
		emptyOutDir: true,
		rollupOptions: {
			input: {
				main: new URL("./src/index.html", import.meta.url).pathname,
				builder: new URL("./src/builder/index.html", import.meta.url).pathname,
				player: new URL("./src/player/index.html", import.meta.url).pathname,
			},
		},
	},
	optimizeDeps: {
		exclude: [
			// Without this, Vite can't load WASM file
			"@sqlite.org/sqlite-wasm",
			"@diffusionstudio/vits-web",
		],
	},
	resolve: {
		alias: {
			"@": new URL("./src", import.meta.url).pathname,
		},
	},
	worker: {
		// onnxruntime-web is not compatible with "iife" format (default value)
		format: "es",
	},
	plugins: [gleam(), elm()],
});
