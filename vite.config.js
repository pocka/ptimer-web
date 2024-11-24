// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { gleam } from "@pocka/rollup-plugin-gleam";
import { defineConfig } from "vite";

export default defineConfig({
	root: new URL("./src", import.meta.url).pathname,
	build: {
		outDir: "../dist",
		emptyOutDir: true,
		rollupOptions: {
			input: {
				main: new URL("./src/index.html", import.meta.url).pathname,
				builder: new URL("./src/builder/index.html", import.meta.url).pathname,
				castle: new URL("./src/castle/index.html", import.meta.url).pathname,
				simple: new URL("./src/simple/index.html", import.meta.url).pathname,
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
	plugins: [gleam()],
});
