// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor } from "@storybook/test";

export default {
	render() {
		const container = document.createElement("div");
		container.style.display = "flex";
		container.style.flexDirection = "column";
		container.style.gap = "8px";

		const output = document.createElement("output");

		const button = document.createElement("button");
		button.textContent = "Button";
		button.type = "button";
		button.addEventListener("click", () => {
			output.value = "Clicked";
		});

		container.appendChild(button);
		container.appendChild(output);

		return container;
	},
} satisfies Meta;

type Story = StoryObj;

export const Static = {} satisfies Story;

export const Test = {
	async play({ canvas }) {
		await userEvent.click(canvas.getByRole("button"));
		await waitFor(() => expect(canvas.getByRole("status")).toHaveValue("Clicked"));
	},
} satisfies Story;
