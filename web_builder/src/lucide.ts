// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import {
	ArrowDownUp,
	Ban,
	ChevronDown,
	ClipboardList,
	CornerLeftDown,
	createElement,
	Download,
	FileMusic,
	FilePlus,
	FolderOpen,
	Globe,
	GripHorizontal,
	type IconNode,
	ListOrdered,
	ListPlus,
	Menu,
	OctagonX,
	Play,
	ScrollText,
	Speech,
	Square,
	Trash2,
} from "lucide";

function createLucideCustomElement(icon: IconNode): typeof HTMLElement {
	return class extends HTMLElement {
		constructor() {
			super();

			const shadow = this.attachShadow({ mode: "open" });

			const style = document.createElement("style");
			style.textContent = ":host{display:inline-flex;}.icon{width:auto;height:1em;}";
			shadow.appendChild(style);

			const svg = createElement(icon);
			svg.classList.add("icon");
			shadow.appendChild(svg);
		}
	};
}

export function register() {
	customElements.define("lucide-arrow-down-up", createLucideCustomElement(ArrowDownUp));
	customElements.define("lucide-ban", createLucideCustomElement(Ban));
	customElements.define("lucide-chevron-down", createLucideCustomElement(ChevronDown));
	customElements.define("lucide-corner-left-down", createLucideCustomElement(CornerLeftDown));
	customElements.define("lucide-download", createLucideCustomElement(Download));
	customElements.define("lucide-list-ordered", createLucideCustomElement(ListOrdered));
	customElements.define("lucide-list-plus", createLucideCustomElement(ListPlus));
	customElements.define("lucide-file-music", createLucideCustomElement(FileMusic));
	customElements.define("lucide-file-plus", createLucideCustomElement(FilePlus));
	customElements.define("lucide-globe", createLucideCustomElement(Globe));
	customElements.define("lucide-grip-horizontal", createLucideCustomElement(GripHorizontal));
	customElements.define("lucide-scroll-text", createLucideCustomElement(ScrollText));
	customElements.define("lucide-menu", createLucideCustomElement(Menu));
	customElements.define("lucide-folder-open", createLucideCustomElement(FolderOpen));
	customElements.define("lucide-clipboard-list", createLucideCustomElement(ClipboardList));
	customElements.define("lucide-octagon-x", createLucideCustomElement(OctagonX));
	customElements.define("lucide-play", createLucideCustomElement(Play));
	customElements.define("lucide-speech", createLucideCustomElement(Speech));
	customElements.define("lucide-square", createLucideCustomElement(Square));
	customElements.define("lucide-trash2", createLucideCustomElement(Trash2));
}
