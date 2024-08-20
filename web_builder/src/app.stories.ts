// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import { sampleWav } from "./storybook_data";

import { story } from "./app.gleam";

interface Args {}

export default {
	render: story,
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};

export const CreateFromScratch = {
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

		await userEvent.click(root.getByRole("button", { name: "Assets" }));
		await userEvent.upload(root.getByLabelText(/add asset/i), sampleWav);

		await userEvent.click(root.getByRole("button", { name: "Steps" }));
		await userEvent.selectOptions(root.getByRole("combobox", { name: /sound/i }), "sample.wav");

		// Go to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Compile then download a generated file
		await userEvent.click(root.getByRole("button", { name: /compile/i }));
		await waitFor(() =>
			expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New Timer.ptimer")
		);
	},
} satisfies Story;

export const ChangeInvalidatesDownloadLink = {
	async play(ctx) {
		await CreateFromScratch.play(ctx);

		const root = within(ctx.canvasElement);

		// Change timer name
		await userEvent.click(root.getByRole("button", { name: "Metadata" }));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "{backspace}R");

		// Go to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Make sure the Download link is not active
		await expect(root.getByRole("button", { name: /download/i })).toBeDisabled();

		// Compile again
		await userEvent.click(root.getByRole("button", { name: /compile/i }));
		await waitFor(() =>
			expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New TimeR.ptimer")
		);
	},
} satisfies Story;
