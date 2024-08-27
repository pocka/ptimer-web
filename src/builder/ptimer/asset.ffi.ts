// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Asset } from "@/builder/ptimer";

export function fromFile(id: number, file: File): Asset {
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
