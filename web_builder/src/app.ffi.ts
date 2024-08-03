// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/app.module.css";

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/app.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function openFilePicker(accept: string, onSelect: (file: File) => void): void {
	const input = document.createElement("input");
	input.type = "file";
	input.accept = accept;
	input.addEventListener("change", ev => {
		ev.preventDefault();
		ev.stopPropagation();

		if (!input.files?.length) {
			return;
		}

		const item = input.files.item(0);
		if (!item) {
			return;
		}

		onSelect(item);
	}, {
		once: true,
	});

	input.click();
}
