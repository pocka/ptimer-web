// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { type Meta, type StoryObj } from "@storybook/html";
import { expect, userEvent, waitFor, within } from "@storybook/test";

import { sampleWav } from "./storybook_data";

import { story } from "./app.gleam";

interface Args {}

export default {
	render: story,
	parameters: {
		app: "builder",
	},
} satisfies Meta<Args>;

type Story = StoryObj<Args>;

export const Demo: Story = {};

export const CreateFromScratch = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		await waitFor(() => userEvent.click(root.getByRole("button", { name: "Logs" })));
		await waitFor(() => expect(root.getByText(/Loaded Ptimer engine/)).toBeInTheDocument(), {
			timeout: 3000,
		});

		const shouldPressCreateButton = !root.queryByText(/This browser does not implement Transferable Streams/);

		await userEvent.click(root.getByRole("button", { name: "Metadata" }));

		if (shouldPressCreateButton) {
			await userEvent.click(root.getByRole("button", { name: /Create new/i }));
		}

		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "New Timer");
		await userEvent.type(root.getByRole("textbox", { name: /description/i }), "Description text,\nSecond line.");
		await userEvent.type(root.getByRole("textbox", { name: /lang/i }), "{backspace}{backspace}GB");

		await userEvent.click(root.getByRole("button", { name: "Steps" }));
		await userEvent.click(root.getByRole("button", { name: /add step/i }));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "Step One");
		await userEvent.type(root.getByRole("textbox", { name: /description/i }), "Description for{enter}Step One");
		await userEvent.selectOptions(root.getByRole("combobox", { name: /type$/i }), "Timer");
		await userEvent.type(root.getByRole("textbox", { name: /duration/i }), "{backspace}120");

		await userEvent.click(root.getByRole("button", { name: "Assets" }));
		await userEvent.upload(root.getByLabelText(/add asset/i), sampleWav);

		await userEvent.click(root.getByRole("button", { name: "Steps" }));
		await userEvent.selectOptions(root.getByRole("combobox", { name: /sound/i }), "sample.wav");

		// Go to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Compile then download a generated file
		await userEvent.click(root.getByRole("button", { name: /compile/i }));
		await waitFor(() =>
			expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New Timer.ptimer")
		);
	},
} satisfies Story;

export const ChangeInvalidatesDownloadLink = {
	async play(ctx) {
		await CreateFromScratch.play(ctx);

		const root = within(ctx.canvasElement);

		// Change timer name
		await userEvent.click(root.getByRole("button", { name: "Metadata" }));
		await userEvent.type(root.getByRole("textbox", { name: /title/i }), "{backspace}R");

		// Go to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Make sure the Download link is not active
		await expect(root.getByRole("button", { name: /download/i })).toBeDisabled();

		// Compile again
		await userEvent.click(root.getByRole("button", { name: /compile/i }));
		await waitFor(() =>
			expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New TimeR.ptimer")
		);

		await ctx.step("Make sure the old file binary is released", async () => {
			await userEvent.click(root.getByRole("button", { name: "Logs" }));
			await waitFor(() => expect(root.getByText(/invalidate.*url/i)).toBeInTheDocument());
		});
	},
} satisfies Story;

export const CreateFromScratchUsingErrorListJump = {
	async play({ canvasElement }) {
		const root = within(canvasElement);

		// Wait for engine to be ready
		await waitFor(() => userEvent.click(root.getByRole("button", { name: "Logs" })));
		await waitFor(() => expect(root.getByText(/Loaded Ptimer engine/)).toBeInTheDocument(), {
			timeout: 3000,
		});

		// Checks Transferable Streams support because it changes whether the app opens
		// welcome page or not.
		const shouldPressCreateButton = !root.queryByText(/This browser does not implement Transferable Streams/);

		await userEvent.click(root.getByRole("button", { name: "Metadata" }));

		if (shouldPressCreateButton) {
			await userEvent.click(root.getByRole("button", { name: /Create new/i }));
		}

		// Create empty step
		await userEvent.click(root.getByRole("button", { name: "Steps" }));
		await userEvent.click(root.getByRole("button", { name: /add step/i }));

		// Go to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));
		await expect(root.getAllByRole("listitem")).toHaveLength(2);

		// Jump to metadata title
		// NOTE: Due to `listitem` does not expose its text content as name, and testing-library
		//       does not provide a way to query by text AND role, this test has to rely on
		//       order, which is fragile and bad practice.
		await userEvent.click(within(root.getAllByRole("listitem")[0]!).getByRole("button"));

		// Check Metadata scene is active
		await expect(root.getByLabelText(/lang.* code/i)).toBeInTheDocument();

		// Fill metadata title (field should have focus)
		await waitFor(() => expect(root.getByRole("textbox", { name: /title/i })).toHaveFocus());
		await userEvent.keyboard("New Timer");

		// Go back to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Make sure the metadata title error has gone
		await expect(root.getAllByRole("listitem")).toHaveLength(1);

		// Jump to step title
		await userEvent.click(within(root.getByRole("listitem")).getByRole("button"));

		// Check Step scene is active
		await expect(root.getByRole("button", { name: /add step/i })).toBeInTheDocument();

		// Fill step title (field should have focus)
		await waitFor(() => expect(root.getByRole("textbox", { name: /title/i })).toHaveFocus());
		await userEvent.keyboard("Step One");

		// Go back to "Export" scene
		await userEvent.click(root.getByRole("button", { name: "Export" }));

		// Compile
		await userEvent.click(root.getByRole("button", { name: /compile/i }));
		await waitFor(() =>
			expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New Timer.ptimer")
		);
	},
} satisfies Story;

class ElementNotReachableViaTabError extends Error {
	element: Element;

	constructor(msg: string, element: Element) {
		super(msg);
		this.element = element;
	}
}

export const CreateFromScratchOnlyWithKeyboard = {
	async play({ canvasElement, step }) {
		const root = within(canvasElement);

		async function tabTo(element: HTMLElement): Promise<void> {
			await step("Focus an element using Tab key", async () => {
				for (let i = 0; i < 100; i++) {
					if (element === document.activeElement) {
						return;
					}

					await userEvent.tab();
				}

				throw new ElementNotReachableViaTabError("Cannot reach the element", element);
			});
		}

		// Wait for initial loading
		await waitFor(() => root.getByRole("button", { name: "Logs" }));

		await step("Check logs for engine load message", async () => {
			await tabTo(root.getByRole("button", { name: "Logs" }));
			await userEvent.keyboard("{enter}");
			await waitFor(() => expect(root.getByText(/Loaded Ptimer engine/)).toBeInTheDocument(), {
				timeout: 3000,
			});
		});

		await step("Create new timer", async () => {
			const shouldPressCreateButton = !root.queryByText(/This browser does not implement Transferable Streams/);

			await tabTo(root.getByRole("button", { name: "Metadata" }));
			await userEvent.keyboard("{enter}");

			if (shouldPressCreateButton) {
				await tabTo(root.getByRole("button", { name: /Create new/i }));
				await userEvent.keyboard("{enter}");
			}
		});

		await step("Fill metadata", async () => {
			await tabTo(root.getByRole("textbox", { name: /title/i }));
			await userEvent.keyboard("New Timer");
			await userEvent.tab();
			await userEvent.keyboard("Description text,\nSecond line.");
			await userEvent.tab();
			await userEvent.keyboard("{backspace}{backspace}GB");
		});

		await step("Create a step", async () => {
			await tabTo(root.getByRole("button", { name: "Steps" }));
			await userEvent.keyboard("{enter}");

			await tabTo(root.getByRole("button", { name: /add step/i }));
			await userEvent.keyboard("{enter}");
			await tabTo(root.getByRole("textbox", { name: /title/i }));
			await userEvent.keyboard("Step One");
			await userEvent.tab();
			await userEvent.keyboard("Description for{enter}Step One");
			await userEvent.tab();
			// Asset is not registered yet, so skipping sound field
			await userEvent.tab();

			const typeCombobox = root.getByRole("combobox", { name: /type$/i });
			await expect(typeCombobox).toHaveFocus();
			await userEvent.selectOptions(typeCombobox, "Timer");

			await userEvent.tab();
			await userEvent.keyboard("{backspace}120");
		});

		await step("Register an asset", async () => {
			await tabTo(root.getByRole("button", { name: "Assets" }));
			await userEvent.keyboard("{enter}");

			const addAssetButton = root.getByLabelText(/add asset/i);
			await tabTo(addAssetButton);
			await userEvent.upload(addAssetButton, sampleWav);
		});

		await step("Use the registered asset in a step", async () => {
			await tabTo(root.getByRole("button", { name: "Steps" }));
			await userEvent.keyboard("{enter}");

			const soundCombobox = root.getByRole("combobox", { name: /sound/i });
			await tabTo(soundCombobox);
			await userEvent.selectOptions(soundCombobox, "sample.wav");
		});

		await step("Compile the timer and check it generates a link", async () => {
			await tabTo(root.getByRole("button", { name: "Export" }));
			await userEvent.keyboard("{enter}");

			await tabTo(root.getByRole("button", { name: /compile/i }));
			await userEvent.keyboard("{enter}");

			await waitFor(() =>
				expect(root.getByRole("link", { name: /download/i })).toHaveAttribute("download", "New Timer.ptimer")
			);

			await tabTo(root.getByRole("link", { name: /download/i }));
		});
	},
} satisfies Story;
