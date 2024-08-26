// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import SQLite

enum FileFormatError: Error {
	case noMetadata
}

struct Metadata {
	let version: String
	let title: String
	let description: String?
	let language: String

	static func fromDB(db: Connection) throws -> Metadata {
		let metadata = Table("metadata")

		let version = Expression<String>("version")
		let title = Expression<String>("title")
		let description = Expression<String?>("description")
		let language = Expression<String>("lang")

		if let record = try db.pluck(metadata) {
			return Metadata(version: record[version], title: record[title], description: record[description], language: record[language])
		} else {
			throw FileFormatError.noMetadata
		}
	}
}

struct Step {
	let title: String
	let description: String?
	let sound: UInt32?
	let durationSeconds: UInt32?

	static func fromDB(db: Connection) throws -> [Step] {
		let step = Table("step")

		let title = Expression<String>("title")
		let description = Expression<String?>("description")
		let durationSeconds = Expression<Int64?>("duration_seconds")
		let sound = Expression<Int64?>("sound")
		let index = Expression<Int64>("index")

		let iter = try db.prepareRowIterator(step.order(index.asc))

		return try iter.map { (row: Row) throws -> Step in
			return Step(
				title: row[title],
				description: row[description],
				sound: row[sound].map { UInt32($0) },
				durationSeconds: row[durationSeconds].map { UInt32($0) }
			)
		}
	}
}

struct Asset {
	let id: UInt32
	let name: String
	let mime: String
	let notice: String?
	let data: [UInt8]

	static func fromDB(db: Connection) throws -> [Asset] {
		let asset = Table("asset")

		let id = Expression<Int64>("id")
		let name = Expression<String>("name")
		let mime = Expression<String>("mime")
		let notice = Expression<String?>("notice")
		let blob = Expression<SQLite.Blob>("data")

		let iter = try db.prepareRowIterator(asset)

		return try iter.map { (row: Row) throws -> Asset in
			return Asset(
				id: UInt32(row[id]),
				name: row[name],
				mime: row[mime],
				notice: row[notice],
				data: row[blob].bytes
			)
		}
	}
}

struct Ptimer {
	let metadata: Metadata
	let steps: [Step]
	let assets: [Asset]

	static func fromLocalFile(filepath: String) throws -> Ptimer {
		let db = try Connection(filepath, readonly: true)

		let metadata = try Metadata.fromDB(db: db)

		let steps = try Step.fromDB(db: db)

		let assets = try Asset.fromDB(db: db)

		return Ptimer(metadata: metadata, steps: steps, assets: assets)
	}
}
