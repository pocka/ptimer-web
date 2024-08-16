// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import {
	HEARTBEAT,
	type HeartbeatRequest,
	type HeartbeatResponse,
	isResponseMessage,
	PARSE,
	type ParseRequest,
	type ParseResponse,
	request,
} from "@/engine/message";

import { type Asset, type Ptimer } from "@/ptimer";

class Engine {
	#worker: Worker;

	constructor(worker: Worker) {
		this.#worker = worker;
	}

	parse(file: File): Promise<Ptimer> {
		const stream = file.stream();

		const req = request<ParseRequest>(PARSE, { data: stream });

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: Requested parsing");
			console.log("Filename");
			console.info(file.name);
			console.log("MIME");
			console.info(file.type);
			console.log("Size");
			console.info(file.size);
			console.log("Last modified");
			console.info(new Date(file.lastModified));
			console.log("Request");
			console.info(req);
			console.groupEnd();
		}

		return new Promise((resolve, reject) => {
			const onMessage = (ev: MessageEvent) => {
				if (!isResponseMessage(ev.data)) {
					console.warn("Illegal response message sent from engine worker.", {
						message: ev.data,
					});
					return;
				}

				if (ev.data.id !== req.id) {
					return;
				}

				const resp = ev.data as ParseResponse;

				if (!resp.payload.ok) {
					reject(resp.payload.error);

					if (import.meta.env.DEV) {
						console.groupCollapsed("%cDEBUG: Failed to parse file", "background: #900; color: #fff");
						console.error(resp.payload.error);
						console.log("Request");
						console.info(req);
						console.log("Response");
						console.info(resp);
						console.groupEnd();
					}
					return;
				}

				resolve(resp.payload.data);
				if (import.meta.env.DEV) {
					console.groupCollapsed("DEBUG: File parsed");
					console.info(resp.payload.data);
					console.log("Request");
					console.info(req);
					console.log("Response");
					console.info(resp);
					console.groupEnd();
				}

				this.#worker.removeEventListener("message", onMessage);
			};

			this.#worker.addEventListener("message", onMessage);

			this.#worker.postMessage(req, { transfer: [stream] });
		});
	}
}

type Result<T, E = string> = { value: T } | { error: E };

export function newEngine(callback: (engine: Result<Engine>) => void) {
	const worker = new Worker(new URL("@/engine/worker.ts", import.meta.url), {
		type: "module",
	});

	const req = request<HeartbeatRequest>(HEARTBEAT);

	const onError = (ev: ErrorEvent) => {
		callback({
			error: ev.error instanceof Error ? ev.error.message : String(ev.error),
		});

		worker.removeEventListener("error", onError);
		worker.removeEventListener("message", onMessage);
	};

	const onMessage = (ev: MessageEvent) => {
		if (!isResponseMessage(ev.data)) {
			console.warn("Expected heartbeat response, got unexpected response message.", {
				message: ev.data,
			});
			return;
		}

		if (ev.data.id !== req.id) {
			return;
		}

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: Engine ready");
			console.log("SQLite version");
			console.info((ev.data as HeartbeatResponse).payload.sqliteVersion);
			console.log("Request");
			console.info(req);
			console.log("Response");
			console.info(ev.data);
			console.groupEnd();
		}

		callback({
			value: new Engine(worker),
		});

		worker.removeEventListener("error", onError);
		worker.removeEventListener("message", onMessage);
	};

	worker.addEventListener("error", onError);
	worker.addEventListener("message", onMessage);

	worker.postMessage(req);
}

type ParseError =
	| {
		type: "invalid_sqlite3_file";
	}
	| {
		type: "schema_violation";
	}
	| string;

export function parse(engine: Engine, file: File, callback: (ptimer: Result<Ptimer, ParseError>) => void) {
	engine.parse(file).then(data => {
		callback({
			value: data,
		});
	}).catch(err => {
		callback({
			error: err instanceof Error ? err.message : String(err),
		});
	});
}

export function assetFromFile(id: number, file: File): Asset {
	if (import.meta.env.DEV) {
		console.groupCollapsed("DEBUG: Creating asset from File");
		console.log("ID");
		console.info(id);
		console.log("File");
		console.info(file);
		console.groupEnd();
	}

	return {
		id,
		name: file.name,
		mime: file.type,
		url: URL.createObjectURL(file),
		notice: null,
	};
}

export function revokeObjectURL(url: string): void {
	if (import.meta.env.DEV) {
		console.groupCollapsed("DEBUG: Releasing object URL");
		console.log("URL");
		console.info(url);
		console.groupEnd();
	}

	URL.revokeObjectURL(url);
}
