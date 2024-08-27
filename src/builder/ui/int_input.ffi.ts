// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import moduleCss from "@/builder/ui/int_input.module.css";
import textboxModuleCss from "@/builder/ui/textbox.module.css";

export function textboxClassName(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in textboxModuleCss)) {
			console.warn(`Class "${x}" does not exist in @/builder/ui/textbox.module.css`);
		}
	}

	return textboxModuleCss[x] ?? "";
}

export function className(x: string): string {
	if (import.meta.env.DEV) {
		if (!(x in moduleCss)) {
			console.warn(`Class "${x}" does not exist in @/builder/ui/int_input.module.css`);
		}
	}

	return moduleCss[x] ?? "";
}

export function overwriteValue(ev: Event, value: string) {
	if (!(ev.currentTarget instanceof HTMLInputElement)) {
		return;
	}

	ev.currentTarget.value = value;
}
