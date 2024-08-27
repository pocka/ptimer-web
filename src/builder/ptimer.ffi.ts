// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import {
	COMPILE,
	type CompileRequest,
	type CompileResponse,
	HEARTBEAT,
	type HeartbeatRequest,
	type HeartbeatResponse,
	PARSE,
	type ParseRequest,
	type ParseResponse,
} from "@/builder/workers/engine/message";
import { AsyncWorkerMessanger, isResponseMessage, request } from "@/builder/workers/helpers";

import { type Ptimer } from "@/builder/ptimer";

class Engine extends AsyncWorkerMessanger {
	constructor(worker: Worker) {
		super(worker);
	}

	async parse(file: File): Promise<Ptimer> {
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

		const res = await this.send<ParseRequest, ParseResponse>(req, { transfer: [stream] });

		if (!res.payload.ok) {
			if (import.meta.env.DEV) {
				console.groupCollapsed("%cDEBUG: Failed to parse file", "background: #900; color: #fff");
				console.error(res.payload.error);
				console.log("Request");
				console.info(req);
				console.log("Response");
				console.info(res);
				console.groupEnd();
			}

			throw res.payload.error;
		}

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: File parsed");
			console.info(res.payload.data);
			console.log("Request");
			console.info(req);
			console.log("Response");
			console.info(res);
			console.groupEnd();
		}

		return res.payload.data;
	}

	async compile(timer: Ptimer): Promise<File> {
		const req = request<CompileRequest>(COMPILE, { timer });

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: Requested compilation");
			console.log("Timer");
			console.info(timer);
			console.log("Request");
			console.info(req);
			console.groupEnd();
		}

		const res = await this.send<CompileRequest, CompileResponse>(req);

		if (!res.payload.ok) {
			if (import.meta.env.DEV) {
				console.groupCollapsed("%cDEBUG: Failed to compile timer", "background: #900; color: #fff");
				console.error(res.payload.error);
				console.log("Request");
				console.info(req);
				console.log("Response");
				console.info(res);
				console.groupEnd();
			}

			throw res.payload.error;
		}

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: File compiled");
			console.log("Byte size");
			console.info(res.payload.data.byteLength);
			console.log("Request");
			console.info(req);
			console.log("Response");
			console.info(res);
			console.groupEnd();
		}

		return new File([res.payload.data], `${timer.metadata.title}.ptimer`, {
			type: "application/x-ptimer",
		});
	}
}

type Result<T, E = string> = { value: T } | { error: E };

export function newEngine(callback: (engine: Result<Engine>) => void) {
	const worker = new Worker(new URL("@/builder/workers/engine/worker.ts", import.meta.url), {
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

type CompileError = string;

export function compile(engine: Engine, timer: Ptimer, callback: (url: Result<string, CompileError>) => void): void {
	engine.compile(timer).then(file => {
		const url = URL.createObjectURL(file);

		callback({
			value: url,
		});
	}).catch(err => {
		callback({
			error: err instanceof Error ? err.message : String(err),
		});
	});
}
