// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { CompiledElmNamespaces } from "./Main.elm";
import { isFileLoaderToMainThreadMessage, type MainThreadToFileLoaderMessage } from "./messages";

const PREFERENCES_STORAGE_KEY = "ptimer_prefrences_v1";
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

function showError(error: unknown, label?: string): void {
	const container = document.getElementById("splash-error");
	if (!container) {
		return;
	}

	const el = document.createElement("li");
	el.classList.add("splash-error--item");

	const labelEl = document.createElement("span");
	labelEl.classList.add("splash-error--item--label");

	if (label) {
		labelEl.textContent = `ERROR (${label})`;
	} else {
		labelEl.textContent = "ERROR";
	}

	el.appendChild(labelEl);

	const message = document.createElement("span");
	message.textContent = error instanceof Error ? error.message : typeof error === "string" ? error : String(error);

	el.appendChild(message);
	container.appendChild(el);
}

interface TaskOptions {
	/**
	 * Document ID of an element representing task's status.
	 */
	statusID: string;

	name?: string;
}

async function runTask<T>(task: Promise<T>, { statusID, name }: TaskOptions): Promise<T> {
	const el = document.getElementById(statusID);
	if (!el) {
		return Promise.reject(new Error(`Splash screen is not loaded: element with ID=${statusID} does not exist`));
	}

	try {
		const value = await task;

		el.textContent = "Ready";

		return value;
	} catch (error) {
		console.error(error);
		el.textContent = "Error";

		showError(error, name);

		return Promise.reject(error);
	}
}

async function main() {
	const [, Elm, worker] = await Promise.all([
		splashMinDuration(),
		runTask(loadElm(), {
			statusID: "splash_core",
			name: "Application Core",
		}),
		runTask(loadWorker(), {
			statusID: "splash_db",
			name: "Database Engine",
		}),
		runTask(
			Promise.all([
				import("./Main.css"),
				import("./custom_elements"),
			]),
			{
				statusID: "splash_assets",
				name: "Assets",
			},
		),
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

	app.ports.sendWakeLockStatusRequest.subscribe(() => {
		if (!navigator.wakeLock) {
			app.ports.receiveWakeLockState.send({
				type: "NotAvailable",
			});
			return;
		}

		app.ports.receiveWakeLockState.send({
			type: "Unlocked",
		});
	});

	app.ports.sendWakeLockAcquireRequest.subscribe(async () => {
		if (!navigator.wakeLock) {
			app.ports.receiveWakeLockState.send({
				type: "NotAvailable",
			});
			return;
		}

		app.ports.receiveWakeLockState.send({
			type: "AcquiringLock",
		});

		try {
			const wakeLock = await navigator.wakeLock.request("screen");

			wakeLock.addEventListener("release", () => {
				app.ports.receiveWakeLockState.send({
					type: "Unlocked",
				});
			}, { once: true });

			app.ports.receiveWakeLockState.send({
				type: "Locked",
				sentinel: wakeLock,
			});

			return;
		} catch (error) {
			console.warn("Failed to acquire WakeLock: ", error);

			app.ports.receiveWakeLockState.send({
				type: "Unlocked",
			});
			return;
		}
	});

	app.ports.sendWakeLockReleaseRequest.subscribe(async sentinel => {
		app.ports.receiveWakeLockState.send({
			type: "ReleasingLock",
		});

		try {
			await sentinel.release();

			app.ports.receiveWakeLockState.send({
				type: "Unlocked",
			});
			return;
		} catch (error) {
			console.warn("Failed to release WakeLock: ", error);

			app.ports.receiveWakeLockState.send({
				type: "Locked",
				sentinel,
			});
			return;
		}
	});

	app.ports.requestAudioElementPlayback.subscribe(id => {
		const el = document.getElementById(id);
		if (!el) {
			console.warn(`AudioElementPlayback: Element (id=${id}) does not exist`);
			return;
		}

		if (!(el instanceof HTMLAudioElement)) {
			console.warn(`AudioElementPlayback: Element (id=${id}) is not a HTMLAudioElement`);
			return;
		}

		el.pause();
		el.currentTime = 0;
		el.play();
	});

	app.ports.requestSavePreferences.subscribe(preferences => {
		localStorage.setItem(PREFERENCES_STORAGE_KEY, JSON.stringify(preferences));
	});

	app.ports.requestLoadPreferences.subscribe(() => {
		const item = localStorage.getItem(PREFERENCES_STORAGE_KEY);
		if (!item) {
			return;
		}

		app.ports.receiveSavedPreferences.send(JSON.parse(item));
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
