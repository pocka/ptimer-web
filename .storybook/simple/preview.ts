// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import mainCSS from "../../src/simple/main.css?url";
import contrastCSS from "../../src/simple/vars-contrast.css?url";
import darkContrastCSS from "../../src/simple/vars-dark-contrast.css?url";
import darkCSS from "../../src/simple/vars-dark.css?url";

function insertStylesheet(url: string, media?: string): void {
	const link = document.createElement("link");

	link.setAttribute("rel", "stylesheet");
	link.setAttribute("href", url);

	if (media) {
		link.setAttribute("media", media);
	}

	document.head.appendChild(link);
}

insertStylesheet(mainCSS);
insertStylesheet(darkCSS, "(prefers-color-scheme: dark)");
insertStylesheet(contrastCSS, "(prefers-contrast: more)");
insertStylesheet(darkContrastCSS, "(prefers-color-scheme: dark) and (prefers-contrast: more)");
