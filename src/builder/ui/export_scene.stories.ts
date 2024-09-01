// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, waitFor, within } from "@storybook/test";

import { type Ptimer } from "@/ptimer";

import { story } from "./export_scene.gleam";

interface Args {
	timer: Ptimer;
}

export default {
	render: story,
	args: {
		timer: {
			metadata: {
				version: "1.0",
				title: "Sample Timer",
				description: null,
				lang: "en-US",
			},
			steps: [
				{
					id: 0,
					title: "Step 1",
					description: null,
					duration_seconds: 5,
					sound: null,
				},
			],
			assets: [
				{
					id: 0,
					name: "Sample Asset",
					mime: "text/html",
					notice: null,
					url: "https://example.com",
				},
			],
		},
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Valid: Story = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => expect(root.getByRole("button", { name: /compile/i })).toBeEnabled());
	},
};

export const MissingRequiredFields: Story = {
	args: {
		timer: {
			metadata: {
				version: "1.0",
				title: "",
				description: null,
				lang: "",
			},
			steps: [
				{
					id: 0,
					title: "",
					description: null,
					duration_seconds: 5,
					sound: 0,
				},
			],
			assets: [
				{
					id: 0,
					name: "",
					mime: "",
					notice: null,
					url: "https://example.com",
				},
			],
		},
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => expect(root.getByRole("button", { name: /compile/i })).toBeDisabled());
	},
};

export const ConstraintsViolations: Story = {
	args: {
		timer: {
			metadata: {
				version: "1.0",
				title: "Sample Timer ".repeat(500),
				description: null,
				lang: "en-US",
			},
			steps: [
				{
					id: 0,
					title: "Step 1 ".repeat(500),
					description: null,
					duration_seconds: -1,
					sound: 1,
				},
			],
			assets: [
				{
					id: 0,
					name: "Sample Asset",
					mime: "text-html",
					notice: null,
					url: "https://example.com",
				},
			],
		},
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => expect(root.getByRole("button", { name: /compile/i })).toBeDisabled());
	},
};

export const NoSteps: Story = {
	args: {
		timer: {
			metadata: {
				version: "1.0",
				title: "Sample Timer",
				description: null,
				lang: "en-US",
			},
			steps: [],
			assets: [],
		},
	},
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => expect(root.getByRole("button", { name: /compile/i })).toBeDisabled());
	},
};
