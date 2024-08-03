// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/ui/menu.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/ui/menu.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}
