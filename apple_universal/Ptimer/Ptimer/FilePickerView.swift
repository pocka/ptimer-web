// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

enum FilePickerError: Error {
	case unableToAccessTheFile
}

struct FilePickerView: View {
	@Binding var pickedFile: Ptimer?

	@State var isFilePickerVisible = false
	@State var fileImporterError: Error? = nil

	var body: some View {
		VStack {
			Button {
				isFilePickerVisible = true
			} label: {
				Text("Open .ptimer file")
			}
			.controlSize(.extraLarge)
			.keyboardShortcut(.return)
			.fileImporter(
				isPresented: $isFilePickerVisible,
				allowedContentTypes: [.init(exportedAs: "jp.pocka.Ptimer-timer-document")],
				onCompletion: { result in
					switch result {
					case let .success(url):
						if !url.startAccessingSecurityScopedResource() {
							fileImporterError = FilePickerError.unableToAccessTheFile
						}

						do {
							pickedFile = try Ptimer.fromLocalFile(filepath: url.path(percentEncoded: false))
						} catch {
							print(error)
							fileImporterError = error
						}
					case let .failure(error):
						fileImporterError = error
					}
				}
			)

			if let err = fileImporterError {
				Text(err.localizedDescription).font(.caption).foregroundStyle(.red)
			}
		}
		.padding()
	}
}

#Preview {
	@State var pickedFile: Ptimer? = Optional.none

	return FilePickerView(pickedFile: $pickedFile)
}
