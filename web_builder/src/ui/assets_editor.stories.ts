// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import type { Metadata, Ptimer } from "../ptimer";
import { sampleWav } from "../storybook_data";

import { story } from "./assets_editor.gleam";

const metadata: Metadata = {
	version: "1.0",
	title: "Title",
	description: null,
	lang: "en-US",
};

interface Args {
	timer: Ptimer;

	assets: readonly File[];
}

export default {
	render: story,
	args: {
		timer: {
			metadata,
			steps: [],
			assets: [],
		},
		assets: [sampleWav, sampleWav],
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		assets: [],
	},
};

export const AddAndDelete: Story = {
	args: {
		assets: [],
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.upload(root.getByLabelText(/add asset/i), sampleWav));

		await waitFor(() => expect(root.getByRole("textbox", { name: /name/i })).toHaveValue("sample.wav"));
		await expect(root.getByRole("textbox", { name: /MIME/i })).toHaveValue("audio/wav");

		await userEvent.upload(root.getByLabelText(/add .*asset/i), sampleWav);

		const notices = root.getAllByRole("textbox", { name: /notice/i });
		await waitFor(() => expect(notices).toHaveLength(2));
		await userEvent.type(notices[0]!, "First");
		await userEvent.type(notices[1]!, "Second");
		await userEvent.click(root.getAllByRole("button", { name: /delete/i }).at(0)!);

		await expect(root.getByRole("textbox", { name: /notice/i })).toHaveValue("Second");
	},
};
