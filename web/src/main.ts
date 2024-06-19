// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

interface ElmApp {
	ports: {};
}

async function loadElm(): Promise<{ Main: { init(): ElmApp } }> {
	const { Elm } = await import("./Main.elm");

	return Elm;
}

async function loadSQLite(): Promise<unknown> {
	const { sqlite3Worker1Promiser } = await import("@sqlite.org/sqlite-wasm");

	return new Promise(resolve => {
		const promiser = sqlite3Worker1Promiser({
			onready() {
				resolve(promiser);
			},
		});
	});
}

async function main() {
	const [Elm, sqlite] = await Promise.all([
		loadElm(),
		loadSQLite(),
	]);

	const app = Elm.Main.init();
}

main();
