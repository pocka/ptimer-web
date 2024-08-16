// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";

import type { Metadata, Ptimer } from "../ptimer";

import { story } from "./assets_editor.gleam";

class BufWriter {
	#buf: Uint8Array;
	#index: number = 0;
	#view: DataView;

	constructor(buffer: Uint8Array) {
		this.#buf = buffer;
		this.#view = new DataView(buffer.buffer);
	}

	get buffer() {
		return this.#buf;
	}

	write(data: string): void;
	write(data: number, byteSize?: 1 | 2 | 4): void;
	write(data: ArrayBufferView): void;
	write(data: unknown, byteSize: number = 2): void {
		if (typeof data === "string") {
			const enc = new TextEncoder();

			const view = this.#buf.subarray(this.#index);

			const { written } = enc.encodeInto(data, view);

			this.#index += written;

			return;
		}

		if (typeof data === "number") {
			switch (byteSize) {
				case 1: {
					this.#buf[this.#index++] = data;
					return;
				}
				case 2: {
					this.#view.setUint16(this.#index, data, true);
					this.#index += 2;
					return;
				}
				case 4: {
					this.#view.setUint32(this.#index, data, true);
					this.#index += 4;
					return;
				}
			}
		}

		if (ArrayBuffer.isView(data)) {
			this.#buf.set(new Uint8Array(data.buffer, data.byteOffset, data.byteLength), this.#index);
			this.#index += data.byteLength;
			return;
		}

		throw new Error("BufWriter.write: Unsupported data type");
	}
}

function wav(data: Int16Array, sampleRate: number): Blob {
	const byteLength = data.byteLength + 44;
	const writer = new BufWriter(new Uint8Array(byteLength));

	// FileTypeBlocID
	writer.write("RIFF");
	// FileSize
	writer.write(byteLength - 8, 4);
	// FileFormatID
	writer.write("WAVE");

	// FormatBlocID
	writer.write("fmt ");
	// BlocSize
	writer.write(16, 4);
	// AudioFormat (1: PCM integer)
	writer.write(1, 2);
	// NbrChannels
	writer.write(1, 2);
	// Frequence
	writer.write(sampleRate, 4);
	// BytePerSec
	writer.write(sampleRate * 2, 4);
	// BytePerBloc
	writer.write(2, 2);
	// BitsPerSample
	writer.write(16, 2);

	// DataBlocID
	writer.write("data");
	// DataSize
	writer.write(data.byteLength, 4);
	// SampledData
	writer.write(data);

	return new Blob([writer.buffer], {
		type: "audio/wav",
	});
}

function sineWavFile(level: number, pitch: number, durationInSeconds: number): File {
	const sampleRate = 44100;

	const samplesLength = Math.ceil(sampleRate * durationInSeconds);

	const buffer = new Int16Array(samplesLength);

	for (let i = 0; i < samplesLength; i++) {
		const y = Math.sin(i / sampleRate * pitch);

		buffer[i] = Math.round(y * (0xffff >> 1) * level);
	}

	return new File([wav(buffer, sampleRate)], "sample.wav", {
		type: "audio/wav",
	});
}

const sampleWav = sineWavFile(0.8, 5000, 1);

const metadata: Metadata = {
	title: "Title",
	description: null,
	lang: "en-US",
};

interface Args {
	timer: Ptimer;

	assets: readonly File[];
}

export default {
	render: story,
	args: {
		timer: {
			metadata,
			steps: [],
			assets: [],
		},
		assets: [sampleWav, sampleWav],
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Playground: Story = {};

export const Empty: Story = {
	args: {
		assets: [],
	},
};
