// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { createElement, type IconNode, Lock, LockOpen, Upload, Volume2, VolumeX } from "lucide";

function createLucideCustomElement(icon: IconNode): typeof HTMLElement {
	return class extends HTMLElement {
		constructor() {
			super();

			const shadow = this.attachShadow({ mode: "open" });

			const svg = createElement(icon);
			svg.classList.add("icon");
			svg.style.width = "auto";
			svg.style.height = "1em";
			shadow.appendChild(svg);
		}
	};
}

export const LucideUpload = createLucideCustomElement(Upload);

customElements.define("lucide-upload", LucideUpload);

export const LucideLockOpen = createLucideCustomElement(LockOpen);

customElements.define("lucide-lock-open", LucideLockOpen);

export const LucideLock = createLucideCustomElement(Lock);

customElements.define("lucide-lock", LucideLock);

export const LucideVolume2 = createLucideCustomElement(Volume2);

customElements.define("lucide-volume-2", LucideVolume2);

export const LucideVolumeX = createLucideCustomElement(VolumeX);

customElements.define("lucide-volume-x", LucideVolumeX);
