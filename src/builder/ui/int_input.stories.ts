// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import { story } from "./int_input.gleam";

interface Args {
	defaultValue: number;

	unit: string;

	state: "enabled" | "disabled";
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		defaultValue: 99,
		state: "enabled",
		unit: "",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Enabled: Story = {};

export const Disabled: Story = {
	args: {
		state: "disabled",
	},
};

export const WithUnit: Story = {
	args: {
		unit: "px",
	},
};

export const ResetInvalidCharactersOnBlur: Story = {
	args: {
		defaultValue: 5,
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		const el = await waitFor(() => root.getByRole("textbox"));

		await userEvent.type(el, "abcd");
		await userEvent.click(canvasElement);
		await expect(el).toHaveValue("5");

		await userEvent.type(el, "{backspace}123.45");
		await userEvent.click(canvasElement);
		await expect(el).toHaveValue("123");
	},
};

export const ResetInvalidCharactersOnEnter: Story = {
	args: {
		defaultValue: 5,
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		const el = await waitFor(() => root.getByRole("textbox"));

		await userEvent.type(el, "1a{enter}");
		await expect(el).toHaveValue("51");

		await userEvent.type(el, "{backspace}{backspace}123.45{enter}");
		await expect(el).toHaveValue("123");
	},
};
