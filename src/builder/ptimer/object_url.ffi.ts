// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export function revokeObjectURL(url: string): void {
	if (import.meta.env.DEV) {
		console.groupCollapsed("DEBUG: Releasing object URL");
		console.log("URL");
		console.info(url);
		console.groupEnd();
	}

	URL.revokeObjectURL(url);
}
