// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./log.gleam";

interface Args {
	empty: boolean;
}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
	args: {
		empty: false,
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};

export const Empty: Story = {
	args: {
		empty: true,
	},
};
