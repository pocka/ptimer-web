// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./menu.gleam";

interface Args {
	active: boolean;
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		active: true,
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const WithActiveItem: Story = {};

export const NoActiveItems: Story = {
	args: {
		active: false,
	},
};
