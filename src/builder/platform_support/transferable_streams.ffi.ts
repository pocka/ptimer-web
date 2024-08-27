// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export type SupportState =
	| { supported: boolean }
	| { error: string };

export function getSupportStatus(): SupportState {
	try {
		const stream = new ReadableStream();

		structuredClone(stream, { transfer: [stream] });

		return { supported: true };
	} catch (error) {
		if (error instanceof DOMException && error.name === "DataCloneError") {
			return { supported: false };
		}

		console.error("Unexpected occured during Transferable Streams support detection", error);

		// Probably not supported
		return { error: error instanceof Error ? error.message : String(error) };
	}
}
