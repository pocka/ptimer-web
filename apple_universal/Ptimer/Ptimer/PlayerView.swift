// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftUI

enum PlayerViewState {
	case waitingToStart
	case playing(Step, Int, Date, Date)
	case completed
}

struct PlayerView: View {
	let ptimer: Ptimer

	@State var state: PlayerViewState = .waitingToStart

	private func next() {
		switch state {
		case .waitingToStart:
			if let step = ptimer.steps.first {
				state = .playing(step, 0, Date.now, Date.now)
			} else {
				state = .completed
			}
		case let .playing(_, index, _, _):
			if (index + 1) < ptimer.steps.count {
				let nextStep = ptimer.steps[index + 1]
				let startAt = Date.now
				state = .playing(nextStep, index + 1, startAt, startAt)

				if let durationSeconds = nextStep.durationSeconds {
					Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { timer in
						if Date.now.timeIntervalSince(startAt) >= Double(durationSeconds) {
							timer.invalidate()
							next()
						} else {
							state = .playing(nextStep, index + 1, startAt, Date.now)
						}
					})
				}
			} else {
				state = .completed
			}
		case .completed:
			state = .waitingToStart
		}
	}

	var body: some View {
		switch state {
		case .waitingToStart:
			VStack(alignment: .leading, spacing: 8) {
				Text(ptimer.metadata.title).font(.title)

				ptimer.metadata.description.map { description in
					Text(description)
				}

				Spacer()

				VStack(alignment: .trailing) {
					HStack(alignment: .center) {
						Spacer()
						Button {
							next()
						}
						label: {
							Text("Start")
						}
						.keyboardShortcut(.return)
						.controlSize(.large)
					}
				}
			}.padding()
		case let .playing(step, _, startAt, now):
			VStack(alignment: .leading, spacing: 8) {
				Text(step.title).font(.title)

				step.description.map { description in
					Text(description)
				}

				Spacer()

				VStack(alignment: .trailing) {
					HStack(alignment: .center) {
						Spacer()

						if let ds = step.durationSeconds {
							let elapsed = UInt32(now.timeIntervalSince(startAt))

							HStack {
								Text("Wait for")
								Text("\(ds - elapsed)").monospacedDigit()
								Text("seconds")
							}
						} else {
							Button {
								next()
							} label: {
								Text("Next")
							}
							.keyboardShortcut(.return)
							.controlSize(.large)
						}
					}
				}
			}.padding()
		case .completed:
			VStack(alignment: .leading) {
				Text("Completed").font(.title)

				Spacer()

				VStack(alignment: .trailing) {
					HStack(alignment: .center) {
						Spacer()
						Button {
							next()
						}
						label: {
							Text("Done")
						}
						.keyboardShortcut(.return)
						.controlSize(.large)
					}
				}
			}.padding()
		}
	}
}

#Preview {
	let metadata = Metadata(
		title: "Dummy", description: "Dummy timer for preview", language: "en-US"
	)

	let steps: [Step] = [
		Step(title: "Step 1", description: nil, sound: nil, durationSeconds: nil),
		Step(title: "Step 2", description: "With duration", sound: nil, durationSeconds: 5),
	]

	return PlayerView(ptimer: Ptimer(metadata: metadata, steps: steps, assets: []))
}
