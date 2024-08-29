// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { userEvent, waitFor, within } from "@storybook/test";

import { story } from "./metadata_editor.gleam";

interface Args {
	empty: boolean;
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		empty: false,
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		empty: true,
	},
};

export const Fill: Story = {
	args: {
		empty: true,
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		const title = await waitFor(() => root.getByRole("textbox", { name: "Title" }));
		await userEvent.type(title, "My timer");

		await userEvent.type(
			root.getByRole("textbox", { name: "Description" }),
			"This is description.{enter}This is next line.",
		);

		const lang = root.getByRole("textbox", { name: /Language/ });
		await userEvent.clear(lang);
		await userEvent.type(lang, "en-GB");
	},
};
