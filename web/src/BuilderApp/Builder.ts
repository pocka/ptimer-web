// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { BuilderBuilderPorts, ElmApp } from "./Builder.elm";

import { isCompilerToMainThreadMessage, type MainThreadToCompilerMessage } from "../messages";

export function startFileListener(app: ElmApp<BuilderBuilderPorts>): void {
	app.ports.builderBuilderRequestFileUrl.subscribe(file => {
		const url = URL.createObjectURL(file);

		app.ports.builderBuilderReceiveFileUrl.send({
			url,
			mime: file.type,
			name: file.name,
		});
	});

	app.ports.builderBuilderRequestReleaseObjectUrl.subscribe(url => {
		URL.revokeObjectURL(url);
	});

	app.ports.builderBuilderRequestCompile.subscribe(_file => {
	});
}

class Compiler {
	constructor(private worker: Worker) {}

	compile(data: unknown): Promise<string> {
		this.worker.postMessage(
			{
				type: "compile",
				data,
			} satisfies MainThreadToCompilerMessage,
		);

		return new Promise((resolve, reject) => {
			const listener = (ev: MessageEvent) => {
				if (!isCompilerToMainThreadMessage(ev.data)) {
					console.warn("Illegal message sent by compiler worker.", {
						message: ev.data,
					});
					return;
				}

				switch (ev.data.type) {
					case "compile_ok": {
						resolve(ev.data.url);
						this.worker.removeEventListener("message", listener);
						return;
					}
					case "compile_error": {
						reject(ev.data.error);
						this.worker.removeEventListener("message", listener);
						return;
					}
					default: {
						console.warn("Unexpected message sent by compiler worker.", {
							message: ev.data,
						});
						return;
					}
				}
			};

			this.worker.addEventListener("message", listener);
		});
	}

	listen(app: ElmApp<BuilderBuilderPorts>): () => void {
		return app.ports.builderBuilderRequestCompile.subscribe(async data => {
			try {
				const url = await this.compile(data);

				app.ports.builderBuilderReceiveCompiledFile.send(url);
			} catch (error) {
				console.error("Failed to compile .ptimer file", {
					cause: error,
				});

				app.ports.builderBuilderReceiveCompileError.send(
					error instanceof Error ? error.message : typeof error === "string" ? error : String(error),
				);
			}
		});
	}
}

export async function createCompiler(): Promise<Compiler> {
	const worker = new Worker(
		new URL("../workers/compiler.ts", import.meta.url),
		{ type: "module" },
	);

	return new Promise((resolve, reject) => {
		const listener = (ev: MessageEvent) => {
			if (!isCompilerToMainThreadMessage(ev.data)) {
				console.warn("Illegal message sent by compiler worker.", {
					message: ev.data,
				});
				return;
			}

			if (ev.data.type !== "ready") {
				console.warn("Worker message received before ready message", {
					message: ev.data,
				});
				return;
			}

			resolve(new Compiler(worker));
			worker.removeEventListener("message", listener);
			return;
		};

		worker.addEventListener("message", listener);

		worker.addEventListener("error", ev => {
			reject(ev.error);
		});
	});
}
