// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { isFileLoaderToMainThreadMessage, type MainThreadToFileLoaderMessage } from "../messages";
import type { ElmApp, PtimerParserPorts } from "./Parser.elm";

class Parser {
	constructor(private worker: Worker) {}

	parse(fileOrStream: File | ReadableStream<Uint8Array>) {
		const stream = fileOrStream instanceof ReadableStream ? fileOrStream : fileOrStream.stream();

		this.worker.postMessage(
			{
				type: "file_parse_request",
				data: stream,
			} satisfies MainThreadToFileLoaderMessage,
			{
				transfer: [stream],
			},
		);

		return new Promise((resolve, reject) => {
			const listener = (ev: MessageEvent) => {
				if (!isFileLoaderToMainThreadMessage(ev.data)) {
					console.warn("Illegal message sent by file loader worker.", {
						message: ev.data,
					});
					return;
				}

				switch (ev.data.type) {
					case "file_parsed": {
						resolve(ev.data.file);
						this.worker.removeEventListener("message", listener);
						return;
					}
					case "file_parse_error": {
						reject(ev.data.error);
						this.worker.removeEventListener("message", listener);
						return;
					}
					default: {
						console.warn("Unexpected message sent by file loader worker.", {
							message: ev.data,
						});
						return;
					}
				}
			};

			this.worker.addEventListener("message", listener);
		});
	}

	listen(app: ElmApp<PtimerParserPorts>): () => void {
		return app.ports.ptimerParserRequestParse.subscribe(async file => {
			try {
				const parsed = await this.parse(file);

				app.ports.ptimerParserReceiveParsedFile.send(parsed);
			} catch (err) {
				console.error("Failed to parse .ptimer file", {
					cause: err,
				});

				app.ports.ptimerParserReceiveParseError.send(
					err instanceof Error ? err.message : typeof err === "string" ? err : String(err),
				);
			}
		});
	}
}

export async function createParser(): Promise<Parser> {
	const worker = new Worker(
		new URL("../workers/file_loader.ts", import.meta.url),
		{ type: "module" },
	);

	return new Promise((resolve, reject) => {
		const listener = (ev: MessageEvent) => {
			if (!isFileLoaderToMainThreadMessage(ev.data)) {
				console.warn("Illegal message sent by file loader worker.", {
					message: ev.data,
				});
				return;
			}

			if (ev.data.type !== "ready") {
				console.warn("Unexpected worker message received before ready message", {
					message: ev.data,
				});
				return;
			}

			resolve(new Parser(worker));
			worker.removeEventListener("message", listener);
			return;
		};

		worker.addEventListener("message", listener);

		worker.addEventListener("error", ev => {
			reject(ev.error);
		});
	});
}
