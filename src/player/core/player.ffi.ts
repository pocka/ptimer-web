// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/player/core/player.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/player/core/player.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function raf(callback: () => void): void {
	requestAnimationFrame(() => {
		callback();
	});
}

export function tick(interval: number, callback: (delta: number) => void): void {
	const start = Date.now();

	setTimeout(() => {
		callback(Date.now() - start);
	}, interval);
}
