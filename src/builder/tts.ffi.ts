// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { VoiceId } from "@diffusionstudio/vits-web";

import { AsyncWorkerMessanger, isResponseMessage, request } from "@/builder/workers/helpers";
import {
	HEARTBEAT,
	type HeartbeatRequest,
	RUN,
	type RunRequest,
	type RunResponse,
} from "@/builder/workers/tts/message";

class TTS extends AsyncWorkerMessanger {
	constructor(worker: Worker) {
		super(worker);
	}

	async run(text: string, voiceKey: string): Promise<File> {
		const req = request<RunRequest>(RUN, {
			text,
			voiceKey,
		});

		if (import.meta.env.DEV) {
			console.groupCollapsed("DEBUG: Requested TTS inference");
			console.log("Request");
			console.info(req);
			console.groupEnd();
		}

		const res = await this.send<RunRequest, RunResponse>(req);

		if (!res.payload.ok) {
			if (import.meta.env.DEV) {
				console.groupCollapsed("%cDEBUG: Failed to generate TTS audio", "background: #900; color: #fff");
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
			console.groupCollapsed("DEBUG: Generated TTS audio");
			console.log("Byte size");
			console.info(res.payload.wavData.byteLength);
			console.log("Request");
			console.info(req);
			console.log("Response");
			console.info(res);
			console.groupEnd();
		}

		return new File([res.payload.wavData], `${text}.wav`, {
			type: "audio/wav",
		});
	}
}

type Result<T, E = string> = { value: T } | { error: E };

export function newTTSEngine(callback: (tts: Result<TTS>) => void): void {
	const worker = new Worker(new URL("@/builder/workers/tts/worker.ts", import.meta.url), {
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
			console.groupCollapsed("DEBUG: TTS worker ready");
			console.log("Request");
			console.info(req);
			console.log("Response");
			console.info(ev.data);
			console.groupEnd();
		}

		callback({
			value: new TTS(worker),
		});

		worker.removeEventListener("error", onError);
		worker.removeEventListener("message", onMessage);
	};

	worker.addEventListener("error", onError);
	worker.addEventListener("message", onMessage);

	worker.postMessage(req);
}

interface PickedVoice {
	readonly key: VoiceId;
	readonly displayName: string;
	readonly languageCode: string;
	readonly dataset?: {
		readonly url: string;
		readonly copyright?: string;
		readonly license?: string;
	};
	readonly model?: {
		readonly url: string;
		readonly copyright?: string;
		readonly license?: string;
	};
}

export function getPredefinedVoices(): readonly PickedVoice[] {
	return [
		{
			key: "en_US-hfc_female-medium",
			displayName: "Hi-Fi-CAPTAIN Female",
			languageCode: "en-US",
			dataset: {
				url: "https://ast-astrec.nict.go.jp/en/release/hi-fi-captain/",
				license: "CC BY-NC-SA 4.0",
			},
		},
		{
			key: "en_US-hfc_male-medium",
			displayName: "Hi-Fi-CAPTAIN Male",
			languageCode: "en-US",
			dataset: {
				url: "https://ast-astrec.nict.go.jp/en/release/hi-fi-captain/",
				license: "CC BY-NC-SA 4.0",
			},
		},
		{
			key: "en_GB-cori-medium",
			displayName: "Cori",
			languageCode: "en-GB",
			model: {
				url: "https://brycebeattie.com/files/tts/",
				license: "Public Domain",
			},
		},
		{
			key: "en_GB-northern_english_male-medium",
			displayName: "Northern English Male",
			languageCode: "en-GB",
			dataset: {
				url: "http://www.openslr.org/83/",
				license: "Attribution-ShareAlike 4.0 International",
				copyright: "Copyright 2018, 2019 Google, Inc.",
			},
		},
	];
}

export function run(tts: TTS, text: string, voiceKey: string, callback: (url: Result<string>) => void): void {
	tts.run(text, voiceKey).then(file => {
		callback({ value: URL.createObjectURL(file) });
	}).catch(err => {
		callback({ error: err instanceof Error ? err.message : String(err) });
	});
}
