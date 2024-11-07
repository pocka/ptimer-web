// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import datetime
import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import ptimer

pub type Log {
  Log(timestamp: Int, event: Event)
}

pub fn new(event: Event) -> Log {
  Log(timestamp: datetime.timestamp(datetime.now()), event:)
}

pub type Event {
  System(SystemEvent)
  User(UserEvent)
}

pub type SystemEvent {
  StartedInitialization
  CompletedInitialization
  FailedToInitialize(reason: ptimer.EngineLoadError)

  OpenedFile(filename: String)
  FailedToOpenFile(filename: String, reason: ptimer.ParseError)

  CompletedTimerStep(title: String)
}

pub type UserEvent {
  SelectedFile(filename: String)

  StartedTimer(title: String)

  CompletedUserActionStep(title: String)

  ClearedFile

  EndedTimer(title: String)
}

// VIEW

@external(javascript, "@/simple/app/log.ffi.ts", "className")
fn scoped(x: String) -> String

fn system_event(event: SystemEvent) -> element.Element(msg) {
  case event {
    StartedInitialization -> element.text("Started initialization.")
    CompletedInitialization -> element.text("Completed initialization.")
    FailedToInitialize(reason:) ->
      element.text(
        "Failed to initialize: " <> ptimer.engine_load_error_to_string(reason),
      )

    OpenedFile(filename:) -> element.text("Opened \"" <> filename <> "\".")
    FailedToOpenFile(filename:, reason:) ->
      element.text(
        "Failed to open \""
        <> filename
        <> "\": "
        <> ptimer.parse_error_to_string(reason),
      )

    CompletedTimerStep(title:) ->
      element.text("Completed a step \"" <> title <> "\".")
  }
}

fn user_event(event: UserEvent) -> element.Element(msg) {
  case event {
    SelectedFile(filename:) -> element.text("Selected \"" <> filename <> "\".")
    StartedTimer(title:) -> element.text("Started \"" <> title <> "\".")
    CompletedUserActionStep(title:) ->
      element.text("Completed a step \"" <> title <> "\".")
    ClearedFile -> element.text("Cleared selected file.")
    EndedTimer(title:) -> element.text("Ended \"" <> title <> "\".")
  }
}

pub fn view(item: Log) -> element.Element(msg) {
  html.li([], [
    html.div([class(scoped("entry"))], case item.event {
      System(event) -> [
        html.span([class(scoped("kind"))], [element.text("System")]),
        html.span([class(scoped("line"))], [system_event(event)]),
      ]

      User(event) -> [
        html.span([class(scoped("kind"))], [element.text("User")]),
        html.span([class(scoped("line"))], [user_event(event)]),
      ]
    }),
  ])
}
