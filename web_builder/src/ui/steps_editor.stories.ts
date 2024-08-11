// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import type { Step } from "../ptimer";

import { story } from "./steps_editor.gleam";

interface Args {
	steps: readonly Step[];
}

export default {
	render: story,
	args: {
		steps: [
			{
				title: "First Step",
				description: null,
				sound: null,
				duration_seconds: null,
			},
			{
				title: "Second Step",
				description: "Description",
				sound: null,
				duration_seconds: 5,
			},
		],
	},
	parameters: {
		layout: "fullscreen",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		steps: [],
	},
};

export const Deletion: Story = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getAllByRole("button", { name: /delete/i }).at(0)!));
		await expect(root.getByRole("textbox", { name: /title/i })).toHaveValue("Second Step");
	},
};

export const Addition: Story = {
	args: {
		steps: [],
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getByRole("button", { name: /add\s?/i })));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "1st");

		await waitFor(() => userEvent.click(root.getByRole("button", { name: /add\s?/i })));
		await userEvent.type(root.getAllByRole("textbox", { name: /title/i }).at(1)!, "2nd");

		await expect(root.getAllByRole("textbox", { name: /title/i }).at(0)).toHaveValue("1st");
		await expect(root.getAllByRole("textbox", { name: /title/i }).at(1)).toHaveValue("2nd");
	},
};

export const Insertion: Story = {
	args: {
		steps: [
			{
				title: "#1",
				description: null,
				sound: null,
				duration_seconds: null,
			},
			{
				title: "#2",
				description: null,
				sound: null,
				duration_seconds: null,
			},
		],
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getAllByRole("button", { name: /insert\s?/i }).at(1)!));
		await userEvent.type(root.getAllByRole("textbox", { name: /title/i }).at(1)!, "#3");

		await waitFor(() => userEvent.click(root.getAllByRole("button", { name: /insert\s?/i }).at(0)!));
		await userEvent.type(root.getAllByRole("textbox", { name: /title/i }).at(0)!, "#4");

		await expect(root.getAllByRole("textbox", { name: /title/i }).at(0)).toHaveValue("#4");
		await expect(root.getAllByRole("textbox", { name: /title/i }).at(1)).toHaveValue("#1");
		await expect(root.getAllByRole("textbox", { name: /title/i }).at(2)).toHaveValue("#3");
		await expect(root.getAllByRole("textbox", { name: /title/i }).at(3)).toHaveValue("#2");
	},
};

export const ShouldInsertBlankStep: Story = {
	args: {
		steps: [],
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getByRole("button", { name: /add\s?/i })));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "1st title");
		await userEvent.type(root.getByRole("textbox", { name: /description/i }), "1st description");

		await waitFor(() => userEvent.click(root.getByRole("button", { name: /insert\s?/i })));
		await userEvent.type(root.getAllByRole("textbox", { name: /title/i }).at(0)!, "2nd title");
		await userEvent.type(root.getAllByRole("textbox", { name: /description/i }).at(0)!, "2nd description");

		await expect(root.getAllByRole("textbox", { name: /title/i }).at(0)).toHaveValue("2nd title");
		await expect(root.getAllByRole("textbox", { name: /description/i }).at(0)).toHaveValue("2nd description");
		await expect(root.getAllByRole("textbox", { name: /title/i }).at(1)).toHaveValue("1st title");
		await expect(root.getAllByRole("textbox", { name: /description/i }).at(1)).toHaveValue("1st description");
	},
};
