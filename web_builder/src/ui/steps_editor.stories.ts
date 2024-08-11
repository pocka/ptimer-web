// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import { story } from "./steps_editor.gleam";

interface Args {
	empty: boolean;
}

export default {
	render: story,
	args: {
		empty: false,
	},
	parameters: {
		layout: "fullscreen",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		empty: true,
	},
};

export const Deletion: Story = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getAllByRole("button", { name: /delete/i }).at(0)!));
		await expect(root.getByRole("textbox", { name: /title/i })).toHaveValue("Second Step");
	},
};
