// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/builder/ui/button.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/builder/ui/button.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function getFirstFile(ev: Event): File | null {
	if (!ev.currentTarget || !(ev.currentTarget instanceof HTMLInputElement)) {
		return null;
	}

	const file = ev.currentTarget.files?.item(0);

	return file ?? null;
}
