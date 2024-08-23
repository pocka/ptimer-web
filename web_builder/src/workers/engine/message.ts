// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { RequestMessage, ResponseMessage } from "../helpers";

import type { Ptimer } from "../../ptimer";

export const HEARTBEAT = "heartbeat";
export type HeartbeatRequest = RequestMessage<typeof HEARTBEAT>;
export type HeartbeatResponse = ResponseMessage<typeof HEARTBEAT, {
	sqliteVersion: string;
}>;

export const PARSE = "parse";
export type ParseRequest = RequestMessage<typeof PARSE, {
	data: ReadableStream<Uint8Array>;
}>;
export type ParseResponse = ResponseMessage<
	typeof PARSE,
	{ ok: true; data: Ptimer } | { ok: false; error: unknown }
>;

export const COMPILE = "compile";
export type CompileRequest = RequestMessage<typeof COMPILE, {
	timer: Ptimer;
}>;
export type CompileResponse = ResponseMessage<
	typeof COMPILE,
	{
		ok: true;
		data: Uint8Array;
	} | {
		ok: false;
		error: unknown;
	}
>;
