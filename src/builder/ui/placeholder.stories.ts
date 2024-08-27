// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./placeholder.gleam";

interface Args {
	title: string;
	description: string;
}

export default {
	render: story,
	args: {
		title: "No tasks",
		description: "Congratulations! You have zero tasks remaining!",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};
