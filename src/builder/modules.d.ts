// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

declare module "*.gleam" {
	export function main(): void;
	export function story(args: unknown, ctx: unknown): Element;
}
