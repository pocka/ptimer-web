// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export interface FL2MT_Ready {
	type: "ready";

	sqliteVersion: string;
}

export interface FL2MT_FileParsed {
	type: "file_parsed";

	file: {
		metadata: unknown;
		steps: unknown[];
		assets: unknown[];
	};
}

export interface FL2MT_FileParseError {
	type: "file_parse_error";

	error: unknown;
}

export type FileLoaderToMainThreadMessage = FL2MT_Ready | FL2MT_FileParsed | FL2MT_FileParseError;

export function isFileLoaderToMainThreadMessage(x: unknown): x is FileLoaderToMainThreadMessage {
	if (typeof x !== "object" || !x) {
		return false;
	}

	if (!("type" in x && typeof x.type === "string")) {
		return false;
	}

	switch (x.type) {
		case "ready":
		case "file_parsed":
		case "file_parse_error":
			return true;
		default:
			return false;
	}
}

export interface MT2FL_FileParseRequest {
	type: "file_parse_request";

	data: ReadableStream<Uint8Array>;
}

export type MainThreadToFileLoaderMessage = MT2FL_FileParseRequest;

export function isMainThreadToFileLoaderMessage(x: unknown): x is MainThreadToFileLoaderMessage {
	if (typeof x !== "object" || !x) {
		return false;
	}

	if (!("type" in x && typeof x.type === "string")) {
		return false;
	}

	switch (x.type) {
		case "file_parse_request":
			return true;
		default:
			return false;
	}
}
