// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import initSqlite3, { type Database, type Sqlite3Static, type WasmPointer } from "@sqlite.org/sqlite-wasm";

import { type FileLoaderToMainThreadMessage, isMainThreadToFileLoaderMessage } from "../messages";

async function parseFile(
	sqlite: Sqlite3Static,
	stream: ReadableStream<Uint8Array>,
): Promise<void> {
	let db: Database | null = null;
	let dataPointer: WasmPointer | null = null;
	try {
		const buffer = await new Response(stream).arrayBuffer();
		dataPointer = sqlite.wasm.allocFromTypedArray(buffer);

		db = new sqlite.oo1.DB({
			filename: ":memory:",
		});

		const rc = sqlite.capi.sqlite3_deserialize(
			db.pointer!,
			"main",
			dataPointer,
			buffer.byteLength,
			buffer.byteLength,
			sqlite.capi.SQLITE_DESERIALIZE_FREEONCLOSE,
		);

		db.checkRc(rc);

		const metadata = db.exec({
			sql: "SELECT title, description, lang FROM metadata LIMIT 1;",
			returnValue: "resultRows",
			rowMode: "object",
		});

		if (!metadata[0]) {
			throw new Error("File does not have metadata row.");
		}

		const steps = db.exec({
			sql: `
				SELECT
					step.id AS id, title, description,
					duration_seconds, "index", sound
				FROM step
				ORDER BY 'index' ASC;
			`,
			returnValue: "resultRows",
			rowMode: "object",
		});

		const assets = db.exec({
			sql: `
				SELECT
					id, name, mime, data, notice
				FROM asset
				WHERE EXISTS( SELECT 1 FROM step WHERE sound = asset.id );
			`,
			returnValue: "resultRows",
			rowMode: "object",
		});

		self.postMessage(
			{
				type: "file_parsed",
				file: {
					metadata: metadata[0],
					steps,
					assets: assets.map(({ data, ...asset }) => {
						return {
							...asset,
							url: URL.createObjectURL(new Blob([data as Uint8Array], { type: asset.mime as string })),
						};
					}),
				},
			} satisfies FileLoaderToMainThreadMessage,
		);
		return;
	} catch (error) {
		self.postMessage(
			{
				type: "file_parse_error",
				error,
			} satisfies FileLoaderToMainThreadMessage,
		);
		return;
	} finally {
		if (db) {
			db.close();
		}

		if (dataPointer !== null) {
			sqlite.wasm.dealloc(dataPointer);
		}
	}
}

async function main() {
	const sqlite3 = await initSqlite3({
		print: console.debug,
		printErr: console.error,
	});

	addEventListener("message", async ev => {
		if (!isMainThreadToFileLoaderMessage(ev.data)) {
			console.warn("Illegal message sent by main thread.", {
				message: ev.data,
			});
			return;
		}

		switch (ev.data.type) {
			case "file_parse_request": {
				await parseFile(sqlite3, ev.data.data);
				return;
			}
			default: {
				console.warn("Unknown message sent by main thread.", {
					message: ev.data,
				});
				return;
			}
		}
	});

	self.postMessage(
		{
			type: "ready",
			sqliteVersion: sqlite3.version.libVersion,
		} satisfies FileLoaderToMainThreadMessage,
	);
}

main();
