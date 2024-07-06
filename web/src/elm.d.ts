// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

interface ElmToJsPort<Payload> {
	subscribe(callback: (payload: Payload) => void): () => void;
}

interface JsToElmPort<Payload> {
	send(payload: Payload): void;
}

declare module "*.elm" {
	interface ElmApp<Ports> {
		ports: Ports;
	}

	interface ElmDocumentProgram<Ports> {
		init(): ElmApp<Ports>;
	}

	interface CompiledElmNamespaces {
		Main: ElmDocumentProgram<{
			sendSelectedFile: ElmToJsPort<File>;
			receiveParsedFile: JsToElmPort<unknown>;
			receiveFileParseError: JsToElmPort<string>;
			receiveDragEnter: JsToElmPort<FileList | undefined>;
			sendWakeLockStatusRequest: ElmToJsPort<void>;
			sendWakeLockAcquireRequest: ElmToJsPort<void>;
			sendWakeLockReleaseRequest: ElmToJsPort<WakeLockSentinel>;
			receiveWakeLockState: JsToElmPort<
				{ type: "NotAvailable" | "RequestingStatus" | "Unlocked" | "AcquiringLock" | "ReleasingLock" } | {
					type: "Locked";
					sentinel: WakeLockSentinel;
				}
			>;
			requestAudioElementPlayback: ElmToJsPort<string>;
			requestSavePreferences: ElmToJsPort<unknown>;
			requestLoadPreferences: ElmToJsPort<void>;
			receiveSavedPreferences: JsToElmPort<unknown>;
		}>;
	}

	export const Elm: CompiledElmNamespaces;
}
