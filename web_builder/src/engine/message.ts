// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { Ptimer } from "../ptimer";

// --- Base types

const enum MessageType {
	Request = 0,
	Response,
}

export interface RequestMessage<Kind extends string, Payload = undefined> {
	id: string;
	type: MessageType.Request;
	kind: Kind;
	payload: Payload;
}

export interface ResponseMessage<Kind extends string, Payload = undefined> {
	id: string;
	type: MessageType.Response;
	kind: Kind;
	payload: Payload;
}

// --- Utilities

type KindOf<Message extends RequestMessage<string, any> | ResponseMessage<string, any>> = Message extends
	RequestMessage<infer Kind, any> ? Kind
	: Message extends ResponseMessage<infer Kind, any> ? Kind
	: never;

type PayloadOf<Message extends RequestMessage<string, any> | ResponseMessage<string, any>> = Message extends
	RequestMessage<string, infer Payload> ? Payload
	: Message extends ResponseMessage<string, infer Payload> ? Payload
	: never;

export function request<Message extends RequestMessage<string, undefined>>(from: KindOf<Message>): Message;
export function request<Message extends RequestMessage<string, any>>(
	kind: KindOf<Message>,
	payload: PayloadOf<Message>,
): Message;
export function request<Kind extends string, Payload>(
	kind: Kind,
	payload?: Payload,
): RequestMessage<Kind, Payload | undefined> {
	return {
		id: kind + "_" + Date.now(),
		type: MessageType.Request,
		kind,
		payload,
	};
}

export function isRequestMessage(x: unknown): x is RequestMessage<string, unknown> {
	if (typeof x !== "object" || !x) {
		return false;
	}

	if (!("type" in x && x.type === MessageType.Request)) {
		return false;
	}

	if (!("kind" in x && typeof x.kind === "string")) {
		return false;
	}

	if (!("id" in x && typeof x.id === "string")) {
		return false;
	}

	return true;
}

export function response<Message extends ResponseMessage<string, undefined>>(
	from: RequestMessage<KindOf<Message>, undefined>,
): Message;
export function response<Message extends ResponseMessage<string, any>>(
	from: RequestMessage<KindOf<Message>, unknown>,
	payload: PayloadOf<Message>,
): Message;
export function response<Kind extends string, Payload>(
	from: RequestMessage<Kind, unknown>,
	payload?: Payload,
): ResponseMessage<Kind, Payload | undefined> {
	return {
		id: from.id,
		type: MessageType.Response,
		kind: from.kind,
		payload,
	};
}

export function isResponseMessage(x: unknown): x is ResponseMessage<string, unknown> {
	if (typeof x !== "object" || !x) {
		return false;
	}

	if (!("type" in x && x.type === MessageType.Response)) {
		return false;
	}

	if (!("kind" in x && typeof x.kind === "string")) {
		return false;
	}

	if (!("id" in x && typeof x.id === "string")) {
		return false;
	}

	return true;
}

// --- Messages

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
