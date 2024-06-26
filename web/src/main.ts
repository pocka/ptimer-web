// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { CompiledElmNamespaces } from "./Main.elm";
import { isFileLoaderToMainThreadMessage, type MainThreadToFileLoaderMessage } from "./messages";

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

async function loadWorker(): Promise<Worker> {
	const worker = new Worker(
		new URL("workers/file_loader.ts", import.meta.url),
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

			resolve(worker);
			worker.removeEventListener("message", listener);
			return;
		};

		worker.addEventListener("message", listener);

		worker.addEventListener("error", ev => {
			reject(ev.error);
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
	const [, Elm, worker] = await Promise.all([
		splashMinDuration(),
		runTask(loadElm(), "splash_core"),
		runTask(loadWorker(), "splash_db"),
		runTask(import("./Main.css"), "splash_assets"),
	]);

	const app = Elm.Main.init();

	window.addEventListener("dragenter", ev => {
		ev.preventDefault();

		app.ports.receiveDragEnter.send(ev.dataTransfer?.files);
	}, { capture: true });

	window.addEventListener("dragover", ev => {
		ev.preventDefault();
	}, { capture: true });

	app.ports.sendSelectedFile.subscribe(async file => {
		const stream = file.stream();

		worker.postMessage(
			{
				type: "file_parse_request",
				data: stream,
			} satisfies MainThreadToFileLoaderMessage,
			{
				transfer: [stream],
			},
		);
	});

	worker.addEventListener("message", ev => {
		if (!isFileLoaderToMainThreadMessage(ev.data)) {
			console.warn("Illegal message sent by file loader worker.", {
				message: ev.data,
			});
			return;
		}

		switch (ev.data.type) {
			case "file_parsed":
				app.ports.receiveParsedFile.send(ev.data.file);
				return;
			case "file_parse_error":
				console.warn(ev.data.error);
				app.ports.receiveFileParseError.send(
					ev.data.error instanceof Error ? ev.data.error.message : String(ev.data.error),
				);
				return;
		}
	});
}

main();
