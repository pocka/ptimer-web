// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import initSqlite3, { type Database, type Sqlite3Static } from "@sqlite.org/sqlite-wasm";

import { type CompilerToMainThreadMessage, isMainThreadToCompilerMessage } from "../messages";

import initSQL from "bundle-text:../../../sql/init.sql";

interface Metadata {
	title: string;
	lang: string;
	description: string | null;
}

interface Step {
	id: number;
	title: string;
	description: string | null;
	sound: number | null;
	duration_seconds: number | null;
}

interface Asset {
	id: number;
	mime: string;
	name: string;
	notice: string | null;
	url: string;
}

interface Ptimer {
	metadata: Metadata;
	steps: readonly Step[];
	assets: readonly Asset[];
}

async function compile(sqlite: Sqlite3Static, data: Ptimer): Promise<void> {
	let db: Database | null = null;
	try {
		db = new sqlite.oo1.DB({
			filename: ":memory:",
		});

		db.exec(initSQL);

		db.exec({
			sql: `
  			INSERT OR ABORT INTO metadata (
  				title,
  				description,
  				lang
  			) VALUES (
  				?, ?, ?
  			);
      `,
			bind: [data.metadata.title, data.metadata.description, data.metadata.lang],
		});

		const insertAsset = db.prepare(`
			INSERT OR ABORT INTO asset (
				id,
				name,
				mime,
				data,
				notice
			) VALUES (
				?, ?, ?, ?, ?
			);
		`);

		try {
			for (const asset of data.assets) {
				const binary = await fetch(asset.url).then(r => r.arrayBuffer());

				insertAsset.bind([asset.id, asset.name, asset.mime, binary, asset.notice]);
				insertAsset.stepReset();
			}
		} finally {
			insertAsset.finalize();
		}

		const insertStep = db.prepare(`
			INSERT OR ABORT INTO step (
				id,
				title,
				description,
				sound,
				duration_seconds,
				'index'
			) VALUES (
				?, ?, ?, ?, ?, ?
			);
		`);

		try {
			for (let i = 0, l = data.steps.length; i < l; i++) {
				const step = data.steps[i];
				if (!step) {
					continue;
				}

				insertStep.bind([
					step.id,
					step.title,
					step.description,
					step.sound,
					step.duration_seconds,
					i,
				]);
				insertStep.stepReset();
			}
		} finally {
			insertStep.finalize();
		}

		// <https://sqlite.org/wasm/doc/trunk/cookbook.md#impexp>
		const bytes = sqlite.capi.sqlite3_js_db_export(db);
		const blob = new Blob([bytes.buffer], { type: "application/x-sqlite3" });

		self.postMessage(
			{
				type: "compile_ok",
				url: URL.createObjectURL(blob),
			} satisfies CompilerToMainThreadMessage,
		);
	} catch (error) {
		self.postMessage(
			{
				type: "compile_error",
				error,
			} satisfies CompilerToMainThreadMessage,
		);
	} finally {
		db?.close();
	}
}

async function main() {
	const sqlite3 = await initSqlite3({
		print: console.debug,
		printErr: console.error,
	});

	addEventListener("message", async ev => {
		if (!isMainThreadToCompilerMessage(ev.data)) {
			console.warn("Illegal message sent by main thread", {
				message: ev.data,
			});
			return;
		}

		switch (ev.data.type) {
			case "compile": {
				await compile(sqlite3, ev.data.data as Ptimer);
				return;
			}
			default: {
				console.warn("Unknown message sent by main thread", {
					message: ev.data,
				});
				return;
			}
		}
	});

	self.postMessage(
		{
			type: "ready",
		} satisfies CompilerToMainThreadMessage,
	);
}

main();
