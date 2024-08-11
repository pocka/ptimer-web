// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import { story } from "./app.gleam";

interface Args {}

export default {
	render: story,
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};

export const CreateFromScratch: Story = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getByRole("button", { name: "Logs" })));
		await waitFor(() => expect(root.getByText(/Loaded Ptimer engine/)).toBeInTheDocument(), {
			timeout: 3000,
		});

		const shouldPressCreateButton = !root.queryByText(/This browser does not implement Transferable Streams/);

		await userEvent.click(root.getByRole("button", { name: "Metadata" }));

		if (shouldPressCreateButton) {
			await userEvent.click(root.getByRole("button", { name: /Create new/i }));
		}

		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "New Timer");
		await userEvent.type(root.getByRole("textbox", { name: /description/i }), "Description text,\nSecond line.");
		await userEvent.type(root.getByRole("textbox", { name: /lang/i }), "{backspace}{backspace}GB");

		await userEvent.click(root.getByRole("button", { name: "Steps" }));
		await userEvent.click(root.getByRole("button", { name: /add step/i }));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "Step One");
		await userEvent.type(root.getByRole("textbox", { name: /description/i }), "Description for{enter}Step One");
		await userEvent.selectOptions(root.getByRole("combobox", { name: /type$/i }), "Timer");
		await userEvent.type(root.getByRole("textbox", { name: /duration/i }), "{backspace}120");
	},
};
