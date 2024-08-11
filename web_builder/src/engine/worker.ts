// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import initSqlite3, { type Database, type Sqlite3Static, type WasmPointer } from "@sqlite.org/sqlite-wasm";

import type { Asset, Metadata, Ptimer, Step } from "../ptimer";

import {
	HEARTBEAT,
	type HeartbeatRequest,
	type HeartbeatResponse,
	isRequestMessage,
	PARSE,
	type ParseRequest,
	type ParseResponse,
	response,
} from "./message";

async function parse(
	sqlite: Sqlite3Static,
	stream: ReadableStream<Uint8Array>,
): Promise<Ptimer> {
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
		}) as unknown as Metadata[];

		if (!metadata[0]) {
			throw new Error("File does not have metadata row.");
		}

		const steps = db.exec({
			sql: `
				SELECT
					step.id AS id, title, description,
					duration_seconds, sound
				FROM step
				ORDER BY 'index' ASC;
			`,
			returnValue: "resultRows",
			rowMode: "object",
		}) as unknown as Step[];

		const assets = db.exec({
			sql: `
				SELECT
					id, name, mime, data, notice
				FROM asset
				WHERE EXISTS( SELECT 1 FROM step WHERE sound = asset.id );
			`,
			returnValue: "resultRows",
			rowMode: "object",
		}) as unknown as (Omit<Asset, "url"> & { data: Uint8Array })[];

		return {
			metadata: metadata[0],
			steps,
			assets: assets.map(({ data, ...asset }) => {
				const blob = new Blob([data], { type: asset.mime });

				return {
					...asset,
					url: URL.createObjectURL(blob),
				};
			}),
		};
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
	// SQLite WASM incorrectly emits OPFS warning regardless of OPFS storage usage.
	// There is no "official" API and this is the only available option (hack).
	// https://sqlite.org/forum/forumpost/6549a274f04ab0b4
	// @ts-ignore
	self.sqlite3ApiConfig = {
		warn(msg: unknown) {
			if (typeof msg === "string" && /OPFS/.test(msg)) {
				return;
			}

			console.warn(msg);
		},
	};

	const sqlite3Promise = initSqlite3({
		print: console.debug,
		printErr: console.error,
	});

	addEventListener("message", async ev => {
		if (!isRequestMessage(ev.data)) {
			console.warn("Illegal request message sent to engine worker.", {
				message: ev.data,
			});
			return;
		}

		const sqlite3 = await sqlite3Promise;

		switch (ev.data.kind) {
			case HEARTBEAT:
				self.postMessage(response<HeartbeatResponse>(ev.data as HeartbeatRequest, {
					sqliteVersion: sqlite3.version.libVersion,
				}));
				return;
			case PARSE: {
				const req = ev.data as ParseRequest;

				try {
					self.postMessage(response<ParseResponse>(req, {
						ok: true,
						data: await parse(sqlite3, req.payload.data),
					}));
				} catch (error) {
					self.postMessage(response<ParseResponse>(req, {
						ok: false,
						error,
					}));
				}
				return;
			}
			default:
				console.warn("Unknown request message sent to engine worker.", {
					message: ev.data,
				});
				return;
		}
	});
}

main();
