// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import { CAPI, Sqlite3Static } from "@sqlite.org/sqlite-wasm";

interface SQLite3Worker1PromiserResponse<Type, Result> {
	type: Type;
	messageId: string;
	result: Result;
}

interface ExecInput<Row> {
	/**
	 * the SQL to run (unless it's provided as the first argument).
	 * The SQL may contain any number of statements.
	 */
	sql: string;

	/**
	 * a single value valid as an argument for Stmt.bind().
	 * This is only applied to the first non-empty statement in the SQL which has any bindable
	 * parameters. (Empty statements are skipped entirely.)
	 */
	bind?: unknown;

	/**
	 * an optional array. If set, the SQL of each executed statement is appended to this array
	 * before the statement is executed (but after it is prepared - we don't have the bounds of the
	 * individual statement until after that). Empty SQL statements are elided. The contents of
	 * each string are identical to the input (e.g. no bound parameter expansion is performed),
	 * the only change is that the input gets parcelled up into individual statements.
	 */
	saveSql?: string[];

	/**
	 * is a string specifying what this function should return:
	 *
	 * - The default value is (usually) `"this"`, meaning that the DB object itself should be
	 *   returned. The exceptions is if the caller passes neither of `callback` nor `returnValue`
	 *   but does pass an explicit `rowMode` then the default `returnValue` is `"resultRows"`,
	 *   described below.
	 *
	 * - `"resultRows"` means to return the value of the `resultRows` option. If `resultRows` is
	 *   not set, this function behaves as if it were set to an empty array.
	 *
	 * - `"saveSql"` means to return the value of the `saveSql` option. If `saveSql` is not set,
	 *   this function behaves as if it were set to an empty array.
	 */
	returnValue?: "this" | "resultRows" | "resultRows";

	/**
	 * if this is an array, the column names of the result set are stored in this array before the
	 * callback (if any) is triggered (regardless of whether the query produces any result rows).
	 * If no statement has result columns, this value is unchanged. Achtung: an SQL result may have
	 * multiple columns with identical names.
	 *
	 * ---
	 * This option applies only to the first statement which has a non-zero result column count,
	 * regardless of whether the statement actually produces any result rows.
	 */
	columnNames?: string[];

	/**
	 * if this is an array, it functions similarly to the `callback` option: each row of the result
	 * set (if any), with the exception that the `rowMode` 'stmt' is not legal. It is legal to use
	 * both `resultRows` and `callback`, but `resultRows` is likely much simpler to use for small
	 * data sets and can be used over a WebWorker-style message interface. `exec()` throws if
	 * `resultRows` is set and `rowMode` is 'stmt'.
	 *
	 * ---
	 * This option applies only to the first statement which has a non-zero result column count,
	 * regardless of whether the statement actually produces any result rows.
	 */
	resultRows?: Row[];

	/**
	 * specifies the type of he callback's first argument. It may be any of...
	 *
	 * - A string describing what type of argument should be passed as the first argument to
	 *   the callback:
	 *   + `'array'` (the default) causes the results of `stmt.get([])` to be passed to the
	 *     `callback` and/or appended to `resultRows`.
	 *   + `'object'` causes the results of `stmt.get(Object.create(null))` to be passed to the
	 *     `callback` and/or appended to `resultRows`. Achtung: an SQL result may have multiple
	 *     columns with identical names. In that case, the right-most column will be the one set
	 *     in this object!
	 *   + `'stmt'` causes the current Stmt to be passed to the callback, but this mode will
	 *     trigger an exception if `resultRows` is an array because appending the statement to
	 *     the array would be downright unhelpful.
	 *
	 * - An integer, indicating a zero-based column in the result row. Only that one single value
	 *   will be passed on.
	 *
	 * - A string with a minimum length of 2 and leading character of `$` will fetch the row as
	 *   an object, extract that one field, and pass that field's value to the callback. Note
	 *   that these keys are case-sensitive so must match the case used in the SQL.
	 *   e.g. `"select a A from t"` with a `rowMode` of `'$A'` would work but `'$a'` would not.
	 *   A reference to a column not in the result set will trigger an exception on the first row
	 *   (as the check is not performed until rows are fetched).
	 *
	 * Any other `rowMode` value triggers an exception.
	 */
	rowMode?: "array" | "object" | "stmt" | number | `$${string}`;
}

interface Message<Type> {
	type: Type;

	/**
	 * OPTIONAL arbitrary value.
	 * The worker will copy it as-is into response messages to assist in client-side dispatching.
	 */
	messageId?: string;
}

interface DbRelatedMessage<Type> extends Message<Type> {
	/**
	 * a db identifier string (returned by `'open'`) which tells the operation which database
	 * instance to work on. If not provided, the first-opened db is used.
	 *
	 * This is an "opaque" value, with no inherently useful syntax or information.
	 * Its value is subject to change with any given build of this API and cannot be used as a
	 * basis for anything useful beyond its one intended purpose.
	 */
	dbId?: string;
}

interface ResponseMessage<Type, Result> extends Message<Type> {
	dbId?: string;

	result: Result;
}

/**
 * A `close` message closes a database.
 */
interface CloseMessage extends DbRelatedMessage<"close"> {
	args?: {
		unlink: boolean;
	};
}

type CloseResponseMessage = ResponseMessage<"close", {
	/**
	 * filename of closed db, or undefined if no db was closed
	 */
	filename: string | undefined;
}>;

/**
 * This operation fetches the serializable parts of the sqlite3 API configuration.
 */
interface ConfigGetMessage extends Message<"config-get"> {
	args?: {};
}

type ConfigGetResponseMessage = ResponseMessage<"config-get", {
	version: Sqlite3Static["version"];

	/**
	 * True if BigInt support is enabled.
	 */
	bigIntEnabled: boolean;

	/**
	 * result of sqlite3.capi.sqlite3_js_vfs_list()
	 */
	vfsList: ReturnType<CAPI["sqlite3_js_vfs_list"]>;
}>;

/**
 * `exec` is the interface for running arbitrary SQL.
 * It is a wrapper around [the oo1.DB.exec() method][oo1] and supports most of its features.
 *
 * All SQL execution is processed through the `exec` operation.
 * It offers most of the features of [the oo1.DB.exec() method][oo1], with a few limitations
 * imposed by the state having to cross thread boundaries.
 *
 * [oo1]: https://sqlite.org/wasm/doc/trunk/api-oo1.md
 */
interface ExecMessage<Row> extends DbRelatedMessage<"exec"> {
	args: string | ExecInput<Row>;
}

type ExecResponseMessage<Row> = ResponseMessage<"exec", ExecInput<Row>>;

/**
 * `export` is a proxy for [sqlite3_js_db_export()][export], returning the database as a byte
 * array.
 *
 * [export]: https://sqlite.org/wasm/doc/trunk/api-c-style.md#sqlite3_js_db_export
 */
type ExportMessage = DbRelatedMessage<"export">;

type ExportResponseMessage = ResponseMessage<"export", {
	byteArray: Uint8Array;

	/**
	 * the db filename
	 */
	filename: string;

	mimetype: "application/x-sqlite3";
}>;

/**
 * The `open` message directs the worker to open a database.
 */
interface OpenMessage extends Message<"open"> {
	args?: {
		/**
		 * the db filename.
		 */
		filename?: string;

		/**
		 * sqlite3_vfs name. Ignored if filename is `":memory:"` or `""`.
		 */
		vfs?: string;
	};
}

type OpenResponseMessage = ResponseMessage<"open", {
	/**
	 * db filename, possibly differing from the input.
	 */
	filename: string;

	dbId: string;

	/**
	 * `true` if the given filename resides in the known-persistent storage, else `false`.
	 */
	persistent: boolean;

	/**
	 * name of the underlying VFS.
	 */
	vfs: string;
}>;

type ValidWorkerMessage<Row> = CloseMessage | ConfigGetMessage | ExecMessage<Row> | ExportMessage;

interface Promiser {
	<Message extends ValidWorkerMessage<any>>(msg: Message): Promise<
		(Message extends CloseMessage ? CloseResponseMessage
			: Message extends ConfigGetMessage ? ConfigGetResponseMessage
			: Message extends ExecMessage<infer Row> ? ExecResponseMessage<Row>
			: Message extends ExportMessage ? ExportResponseMessage
			: never)
	>;
}

declare module "@sqlite.org/sqlite-wasm" {
	export type SQLite3Worker1Promiser = Promiser;

	export type SQLite3Worker1Error = ResponseMessage<"error", {
		operation: string;
		message: string;
		errorClass: string;
		input: unknown;
		stack?: unknown[];
	}>;

	export function sqlite3Worker1Promiser(options: {
		onready(): void;
	}): SQLite3Worker1Promiser;
}
