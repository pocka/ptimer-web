// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/ui/steps_editor.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/ui/steps_editor.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function setDragEffect(event: DragEvent, effect: DataTransfer["effectAllowed"]): void {
	if (event.dataTransfer) {
		event.dataTransfer.effectAllowed = effect;
	}
}
