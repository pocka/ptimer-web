// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { SQLite3Worker1Promiser } from "@sqlite.org/sqlite-wasm";
import type { CompiledElmNamespaces } from "./Main.elm";

const SPLASH_MIN_DURATION_MS = 800;

/**
 * Displaying splash screen for very short time could make a user thinks the app
 * is glitching. Non-disturbing minimal artificial wait is necessary.
 */
function splashMinDuration(): Promise<void> {
	return new Promise((resolve) => {
		setTimeout(() => {
			resolve();
		}, SPLASH_MIN_DURATION_MS);
	});
}

async function loadElm(): Promise<CompiledElmNamespaces> {
	const { Elm } = await import("./Main.elm");

	return Elm;
}

async function loadSQLite(): Promise<SQLite3Worker1Promiser> {
	const { sqlite3Worker1Promiser } = await import("@sqlite.org/sqlite-wasm");

	return new Promise(resolve => {
		const promiser = sqlite3Worker1Promiser({
			onready() {
				resolve(promiser);
			},
		});
	});
}

async function runTask<T>(task: Promise<T>, statusID: string): Promise<T> {
	const el = document.getElementById(statusID);
	if (!el) {
		return Promise.reject(new Error(`Splash screen is not loaded: element with ID=${statusID} does not exist`));
	}

	el.textContent = "...";

	try {
		const value = await task;

		el.textContent = "OK";

		return value;
	} catch (error) {
		console.error(error);
		el.textContent = "NG";

		// TODO: Display error details
		return Promise.reject(error);
	}
}

async function main() {
	const [, Elm, sqlite] = await Promise.all([
		splashMinDuration(),
		runTask(loadElm(), "splash_core"),
		runTask(loadSQLite(), "splash_db"),
	]);

	Elm.Main.init();

	const sqliteConfig = await sqlite({ type: "config-get" });
	console.info(sqliteConfig.result.version.libVersion);
}

main();
