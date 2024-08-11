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
	interface UIDropZonePorts {
		uiDropZoneReceiveDragEnter: JsToElmPort<FileList | undefined>;
	}

	interface PtimerParserPorts {
		ptimerParserRequestParse: ElmToJsPort<File>;
		ptimerParserReceiveParsedFile: JsToElmPort<unknown>;
		ptimerParserReceiveParseError: JsToElmPort<string>;
	}

	interface BuilderBuilderPorts {
		builderBuilderRequestFileUrl: ElmToJsPort<File>;
		builderBuilderReceiveFileUrl: JsToElmPort<{
			url: string;
			mime: string;
			name: string;
		}>;
		builderBuilderRequestReleaseObjectUrl: ElmToJsPort<string>;
		builderBuilderRequestCompile: ElmToJsPort<unknown>;
		builderBuilderReceiveCompiledFile: JsToElmPort<string>;
		builderBuilderReceiveCompileError: JsToElmPort<string>;
	}

	interface ElmApp<Ports> {
		ports: Ports;
	}

	interface ElmDocumentProgram<Ports> {
		init(): ElmApp<Ports>;
	}

	interface CompiledElmNamespaces {
		Main: ElmDocumentProgram<
			& {
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
			}
			& UIDropZonePorts
			& PtimerParserPorts
		>;

		BuilderApp: {
			Main: ElmDocumentProgram<
				& {
					builderRequestInitializingFileLoader: ElmToJsPort<void>;
					builderReceiveFileLoader: JsToElmPort<null>;
					builderReceiveFileLoaderInitializeError: JsToElmPort<string>;
				}
				& UIDropZonePorts
				& PtimerParserPorts
				& BuilderBuilderPorts
			>;
		};
	}

	export const Elm: CompiledElmNamespaces;
}
