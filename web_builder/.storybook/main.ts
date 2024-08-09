// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { StorybookConfig } from "@storybook/html-vite";

export default {
	framework: "@storybook/html-vite",
	stories: ["../src/**/*.stories.ts"],
	addons: ["@storybook/addon-essentials", "@storybook/addon-interactions"],
	core: {
		disableTelemetry: true,
		disableWhatsNewNotifications: true,
	},
} satisfies StorybookConfig;
