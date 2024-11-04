// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./shell.gleam";

type LoadableState = "loading" | "failed" | "loaded";

interface Args {
	full: boolean;
	core: LoadableState;
	engine: LoadableState;
}

export default {
	render: story,
	args: {
		full: false,
		core: "loaded",
		engine: "loaded",
	},
	argTypes: {
		core: {
			control: "radio",
			options: ["loading", "failed", "loaded"],
		},
		engine: {
			control: "radio",
			options: ["loading", "failed", "loaded"],
		},
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Full: Story = {
	args: {
		full: true,
	},
};

export const Loaded: Story = {};

export const Loading: Story = {
	args: {
		core: "loading",
		engine: "loading",
	},
};

export const LoadFailed: Story = {
	args: {
		core: "failed",
		engine: "failed",
	},
};
