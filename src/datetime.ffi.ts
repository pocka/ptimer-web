// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

export function now(): Date {
	return new Date();
}

export function to_timestamp(datetime: Date): number {
	return datetime.valueOf();
}

export function to_locale_string(datetime: Date): string {
	return datetime.toLocaleString();
}
