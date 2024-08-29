// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./selectbox.gleam";

interface Args {
	options: readonly string[];

	defaultValue: string;

	state: "enabled" | "disabled";
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		options: ["foo", "bar", "baz"],
		defaultValue: "bar",
		state: "enabled",
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

export const Disabled: Story = {
	args: {
		state: "disabled",
	},
};

export const NoOptions: Story = {
	args: {
		options: [],
	},
};

export const NoMatchingOption: Story = {
	args: {
		defaultValue: "qux",
	},
};
