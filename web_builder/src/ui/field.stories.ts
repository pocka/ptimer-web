// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./field.gleam";

interface Args {
	label: string;

	note: string;
}

export default {
	render: story,
	args: {
		label: "Field Label",
		note: "",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const WithoutNote: Story = {};

export const WithNote: Story = {
	args: {
		note: "This is a description or note of the field.",
	},
};
