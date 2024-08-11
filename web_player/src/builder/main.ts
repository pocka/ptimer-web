// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import "../custom_elements";

import { Elm } from "../BuilderApp/Main.elm";

import { createCompiler, startFileListener } from "../BuilderApp/Builder";
import { createParser } from "../Ptimer/Parser";
import { listenForDropZoneEvents } from "../UI/DropZone";

async function main() {
	const app = Elm.BuilderApp.Main.init();

	listenForDropZoneEvents(app);
	startFileListener(app);

	try {
		const parser = await createParser();
		const compiler = await createCompiler();

		app.ports.builderReceiveFileLoader.send(null);

		parser.listen(app);
		compiler.listen(app);
	} catch (err) {
		console.error("Failed to initialize parser worker", {
			cause: err,
		});

		app.ports.builderReceiveFileLoaderInitializeError.send(
			err instanceof Error ? err.message : typeof err === "string" ? err : String(err),
		);
	}
}

main();
