// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./steps_editor.gleam";

interface Args {
	empty: boolean;
}

export default {
	render: story,
	args: {
		empty: false,
	},
	parameters: {
		layout: "fullscreen",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		empty: true,
	},
};
