// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./main.gleam";

interface Args {
	state: "NotInitializedYet" | "Initializing" | "FailedToInitialize" | "Idle";
}

export default {
	render: story,
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};

export const NotInitializedYet: Story = {
	args: {
		state: "NotInitializedYet",
	},
};

export const Intializing: Story = {
	args: {
		state: "Initializing",
	},
};

export const FailedToInitialize: Story = {
	args: {
		state: "FailedToInitialize",
	},
};

export const Idle: Story = {
	args: {
		state: "Idle",
	},
};
