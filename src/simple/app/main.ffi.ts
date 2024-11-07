// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/simple/app/main.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/simple/app/main.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function getFilename(file: File): string {
	return file.name;
}

export function getFirstFile(ev: Event): File | null {
	if (!ev.currentTarget || !(ev.currentTarget instanceof HTMLInputElement)) {
		return null;
	}

	const file = ev.currentTarget.files?.item(0);

	return file ?? null;
}

export function interval(ms: number, cb: () => boolean): void {
	const id = setInterval(() => {
		if (!cb()) {
			clearInterval(id);
		}
	}, ms);
}

export function playAudioElement(id: string): void {
	requestAnimationFrame(() => {
		const element = document.getElementById(id);
		if (!element || !(element instanceof HTMLAudioElement)) {
			return;
		}

		element.currentTime = 0;
		element.play();
	});
}

export function stopAudioElement(id: string): void {
	const element = document.getElementById(id);
	if (!element || !(element instanceof HTMLAudioElement)) {
		return;
	}

	element.pause();
	element.currentTime = 0;
}
