// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export function register(): void {
	class PtimerLogo extends HTMLElement {
		constructor() {
			super();

			const shadow = this.attachShadow({ mode: "open" });

			const style = document.createElement("style");
			style.textContent =
				`:host{display:inline-flex;--ptimer-logo-bg:black;--ptimer-logo-fg:white;}.icon{width:auto;height:1em;}`;

			const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
			svg.setAttribute("viewBox", "0 0 400 400");
			svg.setAttribute("fill", "none");
			svg.classList.add("icon");
			svg.innerHTML = `
<rect x="11.9063" width="236.967" height="236.967" rx="12.5" transform="matrix(0.793753 -0.60824 0.793753 0.60824 2.45564 253.985)" fill="var(--ptimer-logo-bg)" stroke="var(--ptimer-logo-fg)" stroke-width="15"/>
<rect x="11.9063" width="236.967" height="236.967" rx="12.5" transform="matrix(0.793753 -0.60824 0.793753 0.60824 2.45564 160.499)" fill="var(--ptimer-logo-bg)" stroke="var(--ptimer-logo-fg)" stroke-width="15"/>
<line x1="7.5" y1="-7.5" x2="113.222" y2="-7.5" transform="matrix(0.745515 -0.666489 0.835831 0.548986 178 177.011)" stroke="var(--ptimer-logo-fg)" stroke-width="15" stroke-linecap="round"/>
<line x1="7.5" y1="-7.5" x2="102.681" y2="-7.5" transform="matrix(0.989277 0.14605 -0.243833 0.969817 159 149.425)" stroke="var(--ptimer-logo-fg)" stroke-width="15" stroke-linecap="round"/>
		`;

			shadow.appendChild(style);
			shadow.appendChild(svg);
		}
	}

	customElements.define("ptimer-logo", PtimerLogo);
}
