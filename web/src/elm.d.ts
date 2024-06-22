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
		}>;
	}

	export const Elm: CompiledElmNamespaces;
}
