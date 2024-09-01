// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import { story } from "./core.gleam";

const enum State {
	NotSelected = "not_selected",
	Opening = "opening",
	FailedToOpen = "failed_to_open",
	Opened = "opened",
}

interface Args {
	state: State;
}

export default {
	render: story,
	args: {
		state: State.NotSelected,
	},
	argTypes: {
		state: {
			control: "radio",
			options: [State.NotSelected, State.Opening, State.FailedToOpen, State.Opened],
		},
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const NotSelected: Story = {};

export const Opening: Story = {
	args: {
		state: State.Opening,
	},
};

export const FailedToOpen: Story = {
	args: {
		state: State.FailedToOpen,
	},
};

export const Opened: Story = {
	args: {
		state: State.Opened,
	},
};
