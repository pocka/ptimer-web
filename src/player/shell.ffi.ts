// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/player/shell.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/player/shell.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function loadCore(
	onError: (error: string) => void,
	onLoad: (init: unknown, update: unknown, view: unknown) => void,
) {
	import("@/player/core.gleam").then((mod: any) => {
		onLoad(mod.init, mod.update, mod.view);
	}).catch(err => {
		onError(err instanceof Error ? err.message : String(err));
	});
}
