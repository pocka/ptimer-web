// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./textbox.gleam";

interface Args {
	defaultValue: string;

	resize: boolean;

	multiline: boolean;

	rows: number;

	state: "enabled" | "disabled";
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		defaultValue: "Textbox",
		state: "enabled",
		rows: 3,
		resize: false,
		multiline: false,
	},
	argTypes: {
		state: {
			control: "radio",
			options: ["enabled", "disabled"],
		},
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Enabled: Story = {};

export const Empty: Story = {
	args: {
		defaultValue: "",
	},
};

export const Disabled: Story = {
	args: {
		state: "disabled",
	},
};

export const Multiline: Story = {
	args: {
		defaultValue: "Foo\nBar",
		multiline: true,
	},
};

export const ResizableMultiline: Story = {
	args: {
		defaultValue: "Foo\nBar",
		multiline: true,
		resize: true,
	},
};
