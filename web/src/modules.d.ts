// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

declare module "*.css" {}

declare module "bundle-text:*" {
	const contents: string;
	export default contents;
}
