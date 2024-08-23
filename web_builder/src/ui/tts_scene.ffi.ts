// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/ui/tts_scene.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/ui/tts_scene.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export { playAudioEl, stopAudioEl } from "@/ui/assets_editor.ffi";
