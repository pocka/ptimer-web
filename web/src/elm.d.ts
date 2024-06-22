// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

declare module "*.elm" {
	interface ElmApp<Ports> {
		ports: Ports;
	}

	interface ElmDocumentProgram<Ports> {
		init(): ElmApp<Ports>;
	}

	interface CompiledElmNamespaces {
		Main: ElmDocumentProgram<{}>;
	}

	export const Elm: CompiledElmNamespaces;
}
