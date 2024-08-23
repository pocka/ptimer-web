// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { predict, type VoiceId } from "@diffusionstudio/vits-web";

import { isRequestMessage, response } from "../helpers";

import {
	HEARTBEAT,
	type HeartbeatRequest,
	type HeartbeatResponse,
	RUN,
	type RunRequest,
	type RunResponse,
} from "./message";

async function main() {
	addEventListener("message", async ev => {
		if (!isRequestMessage(ev.data)) {
			console.warn("Illegal request message sent to engine worker.", {
				message: ev.data,
			});
			return;
		}

		switch (ev.data.kind) {
			case HEARTBEAT:
				self.postMessage(response<HeartbeatResponse>(ev.data as HeartbeatRequest));
				return;

			case RUN: {
				const req = ev.data as RunRequest;

				try {
					const blob = await predict({
						text: req.payload.text,
						voiceId: req.payload.voiceKey as VoiceId,
					});

					const buffer = await blob.arrayBuffer();

					self.postMessage(
						response<RunResponse>(req, {
							ok: true,
							wavData: buffer,
						}),
						{
							transfer: [buffer],
						},
					);
				} catch (error) {
					self.postMessage(response<RunResponse>(req, {
						ok: false,
						error,
					}));
				}
				return;
			}

			default:
				console.warn("Unknown request message sent to engine worker.", {
					message: ev.data,
				});
				return;
		}
	});
}

main();
