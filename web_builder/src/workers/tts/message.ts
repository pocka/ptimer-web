// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { RequestMessage, ResponseMessage } from "../helpers";

export const HEARTBEAT = "heartbeat";
export type HeartbeatRequest = RequestMessage<typeof HEARTBEAT>;
export type HeartbeatResponse = ResponseMessage<typeof HEARTBEAT>;

export const RUN = "run";
export type RunRequest = RequestMessage<typeof RUN, {
	text: string;
	voiceKey: string;
}>;
export type RunResponse = ResponseMessage<
	typeof RUN,
	{
		ok: true;
		wavData: ArrayBuffer;
	} | {
		ok: false;
		error: unknown;
	}
>;
