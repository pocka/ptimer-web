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

export function configureDataTransfer(event: DragEvent, effect: DataTransfer["effectAllowed"]): void {
	if (event.dataTransfer) {
		event.dataTransfer.setData("text/plain", " ");
		event.dataTransfer.effectAllowed = effect;
	}
}

export function runFLIP<T = unknown>(query: string, onUpdate: () => T): void {
	const snapshots = new Map<HTMLElement, DOMRectReadOnly>();

	for (const element of Array.from(document.querySelectorAll(query))) {
		if (!(element instanceof HTMLElement)) {
			continue;
		}

		snapshots.set(element, element.getBoundingClientRect());
	}

	onUpdate();

	const shouldFade = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

	for (const element of Array.from(document.querySelectorAll(query))) {
		if (!(element instanceof HTMLElement)) {
			continue;
		}

		const before = snapshots.get(element);
		if (!before) {
			// Newly created element
			element.animate([
				{ opacity: 0 },
				{ opacity: 1 },
			], {
				easing: "ease-out",
				duration: 200,
				delay: 150,
				fill: "both",
			});
			continue;
		}

		const after = element.getBoundingClientRect();
		if (before.y === after.y) {
			continue;
		}

		if (shouldFade) {
			element.animate([{ opacity: 0 }, { opacity: 1 }], {
				easing: "ease-in",
				duration: 250,
			});
			continue;
		}

		element.animate([
			{ transform: `translateY(${before.y - after.y}px)` },
			{ transform: "translateY(0px)" },
		], {
			easing: "ease-out",
			duration: 250,
		});
	}
}
