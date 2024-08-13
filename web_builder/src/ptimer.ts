// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export interface Ptimer {
	readonly metadata: Metadata;
	readonly steps: readonly Step[];
	readonly assets: readonly Asset[];
}

export interface Metadata {
	readonly title: string;
	readonly description: string | null;
	readonly lang: string;
}

export interface Step {
	readonly id: number;
	readonly title: string;
	readonly description: string | null;
	readonly sound: number | null;
	readonly duration_seconds: number | null;
}

export interface Asset {
	readonly id: number;
	readonly name: string;
	readonly mime: string;
	readonly notice: string | null;

	/** Temporary URL created by `URL.createObjectURL` */
	readonly url: string;
}
