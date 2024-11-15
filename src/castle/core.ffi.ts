// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/castle/core.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/castle/core.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function getFile(ev: Event): File | null {
	if (!(ev.currentTarget instanceof HTMLInputElement)) {
		return null;
	}

	return ev.currentTarget.files?.item(0) ?? null;
}
