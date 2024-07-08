// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import type { ElmApp, UIDropZonePorts } from "./DropZone.elm";

function preventDefault(ev: Event) {
	ev.preventDefault();
}

export function listenForDropZoneEvents(app: ElmApp<UIDropZonePorts>): () => void {
	const onDragEnter = (ev: DragEvent) => {
		ev.preventDefault();

		app.ports.uiDropZoneReceiveDragEnter.send(ev.dataTransfer?.files);
	};

	window.addEventListener("dragenter", onDragEnter);
	window.addEventListener("dragover", preventDefault);

	return () => {
		window.removeEventListener("dragenter", onDragEnter);
		window.removeEventListener("dragover", preventDefault);
	};
}
