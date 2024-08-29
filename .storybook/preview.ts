// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { STORY_PREPARED } from "@storybook/core-events";
import { addons } from "@storybook/preview-api";

import builderCSS from "../src/builder/main.css?url";
import playerInlineCSS from "../src/inline.css?url";
import playerVarsCSS from "../src/vars.css?url";

import * as lucide from "../src/builder/lucide";
import * as logo from "../src/builder/ui/logo";

try {
	// Since these register CustomElements without checking if an element has been
	// already registered, these throws an error after HMR.
	// FIXME: Check if a tag name is occupied inside the register functions.
	lucide.register();
	logo.register();
} catch {}

const chan = addons.getChannel();

function getOrCreateAnchor(): HTMLScriptElement {
	const existing = document.head.querySelector(`script#ptimer_sb_anchor[type="application/json"]`);
	if (existing) {
		return existing as HTMLScriptElement;
	}

	const anchor = document.createElement("script");
	anchor.type = "application/json";
	anchor.id = "ptimer_sb_anchor";
	document.head.appendChild(anchor);

	return anchor;
}

const anchor = getOrCreateAnchor();

function loadCSS(href: string): void {
	if (document.head.querySelector(`link[rel="stylesheet"][href="${href}"]`)) {
		return;
	}

	const link = document.createElement("link");
	link.rel = "stylesheet";
	link.href = href;
	link.dataset.addedAt = Date.now().toString(10);
	document.head.insertBefore(link, anchor);
}

function handleAppParameter(value: unknown): void {
	switch (value) {
		case "player":
		case "builder":
			break;
		default:
			throw new Error(`Illegal "app" parameter: it must be one of "player" or "builder"`);
	}

	if (value === "player") {
		loadCSS(playerInlineCSS);
		loadCSS(playerVarsCSS);
		return;
	}

	loadCSS(builderCSS);
	return;
}

interface StoryPreparedEvent {
	parameters: Record<string, unknown>;
}

chan.on(STORY_PREPARED, (ev: StoryPreparedEvent) => {
	const remainingStyles = document.head.querySelectorAll(`link[rel="stylesheet"][data-added-at]`);
	remainingStyles.forEach(link => {
		document.head.removeChild(link);
	});

	if ("app" in ev.parameters) {
		try {
			handleAppParameter(ev.parameters.app);
		} catch (error) {
			console.warn(error);
		}
	}
});
