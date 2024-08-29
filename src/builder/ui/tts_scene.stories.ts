// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor } from "@storybook/test";

import { story } from "./tts_scene.gleam";

interface Args {
	state: "not_loaded" | "loading" | "failed_to_load";
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		state: "not_loaded",
	},
	argTypes: {
		state: {
			control: "radio",
			options: ["not_loaded", "loading", "failed_to_load"],
		},
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const NotLoaded = {} satisfies Story;

export const Loading = {
	args: {
		state: "loading",
	},
} satisfies Story;

export const FailedToLoad = {
	args: {
		state: "failed_to_load",
	},
} satisfies Story;

export const Generate = {
	async play({ canvas, step }) {
		await step("Activate TTS feature", async () => {
			const activate = await waitFor(() => canvas.getByRole("button", { name: /activate/i }));

			await userEvent.click(activate);
		});

		await step("Generate speech audio", async () => {
			const generate = await waitFor(() => canvas.getByRole("button", { name: /generate/i }), {
				timeout: 10_000,
			});

			await userEvent.type(canvas.getByRole("textbox", { name: /text/i }), "Sample speech text.");

			const lang = canvas.getByRole("combobox", { name: /lang/i });
			await userEvent.selectOptions(lang, "en-US");
			await waitFor(() => expect(lang).toHaveValue("en-US"));

			const voice = canvas.getByRole("combobox", { name: /voice/i });
			await userEvent.selectOptions(voice, "Hi-Fi-CAPTAIN Female");

			await userEvent.click(generate);
		});
	},
	// This feature downloads CDN scripts and downloads assets over internet.
	// Not suitable for automated testing.
	tags: ["skip-test"],
} satisfies Story;
