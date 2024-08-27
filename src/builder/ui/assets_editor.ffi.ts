// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/builder/ui/assets_editor.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/builder/ui/assets_editor.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function playAudioEl(id: string, onCompleted: () => void): void {
	const el = document.getElementById(id);
	if (!el) {
		if (import.meta.env.DEV) {
			console.warn(`Requested playback of #${id}, but corresponding element does not exist`);
		}
		return;
	}

	if (!(el instanceof HTMLAudioElement)) {
		if (import.meta.env.DEV) {
			console.warn(`Requested playback of #${id}, but the element is not an HTMLAudioElement`);
		}
		return;
	}

	el.play();

	const onPaused = () => {
		onCompleted();
		el.removeEventListener("ended", onPaused);
		el.removeEventListener("pause", onPaused);
	};

	el.addEventListener("ended", onPaused);
	el.addEventListener("pause", onPaused);
}

export function stopAudioEl(id: string): void {
	const el = document.getElementById(id);
	if (!el) {
		if (import.meta.env.DEV) {
			console.warn(`Requested playback stop of #${id}, but corresponding element does not exist`);
		}
		return;
	}

	if (!(el instanceof HTMLAudioElement)) {
		if (import.meta.env.DEV) {
			console.warn(`Requested playback stop of #${id}, but the element is not an HTMLAudioElement`);
		}
		return;
	}

	el.pause();
	el.currentTime = 0;
}
