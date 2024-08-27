// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { action } from "@storybook/addon-actions";
import { type StoryContext } from "@storybook/html";

export function render<T = unknown>(
	args: T,
	context: StoryContext<T>,
	onRender: (selector: string, args: T, action: (type: string, payload: unknown) => void) => void,
): Element {
	const element = document.createElement("div");
	element.id = context.id;
	const selector = "#" + element.id;

	const observer = new MutationObserver((mutationList) => {
		for (const mutation of mutationList) {
			mutation.addedNodes.forEach((node) => {
				if (node === element && node.parentNode) {
					onRender(selector, args, (type, payload) => action(type)(payload));
					observer.disconnect();
				}
			});
		}
	});

	observer.observe(context.canvasElement, {
		childList: true,
	});

	return element;
}
