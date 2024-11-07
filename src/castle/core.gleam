// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import castle/core/player
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import ptimer
import ptimer/metadata
import ptimer/step
import storybook

// MODEL

type Timer {
  NotSelected
  Opening
  FailedToOpen(ptimer.ParseError)
  Opened(player.Model)
}

pub opaque type Model {
  Model(engine: ptimer.Engine, timer: Timer)
}

pub fn init(engine: ptimer.Engine) -> #(Model, Effect(Msg)) {
  #(Model(engine:, timer: NotSelected), effect.none())
}

// UPDATE

pub opaque type Msg {
  GotFile(dynamic.Dynamic)
  GotParseResult(Result(ptimer.Ptimer, ptimer.ParseError))
  PlayerMsg(player.Msg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model {
    GotFile(_), Model(timer: Opening, ..) -> #(model, effect.none())

    GotFile(file), Model(engine:, ..) -> #(
      Model(..model, timer: Opening),
      open(engine, file),
    )

    GotParseResult(Ok(timer)), _ -> {
      let #(m, e) = player.init(timer)

      #(Model(..model, timer: Opened(m)), effect.map(e, PlayerMsg))
    }

    GotParseResult(Error(err)), _ -> #(
      Model(..model, timer: FailedToOpen(err)),
      effect.none(),
    )

    PlayerMsg(sub_msg), Model(timer: Opened(sub_model), ..) -> {
      let #(m, e) = player.update(sub_model, sub_msg)

      #(Model(..model, timer: Opened(m)), effect.map(e, PlayerMsg))
    }

    PlayerMsg(_), _ -> #(model, effect.none())
  }
}

// EFFECT

fn open(engine: ptimer.Engine, file: dynamic.Dynamic) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- ptimer.parse(engine, file)

    dispatch(GotParseResult(result))
  })
}

// VIEW

@external(javascript, "@/castle/core.ffi.ts", "className")
fn scoped(x: String) -> String

@external(javascript, "@/castle/core.ffi.ts", "getFile")
fn get_file(ev: dynamic.Dynamic) -> dynamic.Dynamic

const drag_and_drop_text = "Or drag and drop a .ptimer file."

fn file_picker(
  attrs: List(Attribute(msg)),
  opening: Bool,
  on_pick: fn(dynamic.Dynamic) -> msg,
) -> Element(msg) {
  html.label([class(scoped("file-picker")), ..attrs], [
    html.input([
      class(scoped("visually-hidden")),
      attribute.type_("file"),
      attribute.disabled(opening),
      attribute.accept([".ptimer"]),
      event.on("input", fn(ev) {
        ev
        |> get_file
        |> dynamic.optional(dynamic.dynamic)
        |> result.map(fn(file) {
          case file {
            Some(file) -> Ok(on_pick(file))
            _ -> Error([])
          }
        })
        |> result.flatten
      }),
    ]),
    html.span([class(scoped("file-picker-bg"))], []),
    html.span([class(scoped("file-picker-label"))], [
      case opening {
        True -> text("Opening...")
        False -> text("Open\nTimer File")
      },
    ]),
    {
      let char_count = string.length(drag_and_drop_text)

      // Do not let Screen Readers read individual chunks separately.
      html.span(
        [
          class(scoped("circular-text")),
          attribute.style([#("--_length", int.to_string(char_count))]),
          attribute.attribute("aria-hidden", "true"),
        ],
        {
          drag_and_drop_text
          |> string.split(on: "")
          |> list.index_map(fn(char, i) {
            html.span(
              [
                class(scoped("circular-char")),
                attribute.style([#("--_index", int.to_string(i))]),
              ],
              [text(char)],
            )
          })
        },
      )
    },
    html.span([class(scoped("visually-hidden"))], [text(drag_and_drop_text)]),
  ])
}

fn menu_item(
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.button([class(scoped("menu-button")), ..attrs], children)
}

fn menu_item_index(i: Int) -> Attribute(Msg) {
  attribute.style([#("--_index", int.to_string(i))])
}

fn menu_scene(model: Model) -> Element(Msg) {
  let visibility_class = case model.timer {
    Opened(_) -> class(scoped("hidden"))
    _ -> class(scoped("visible"))
  }

  html.div([class(scoped("layout")), visibility_class], [
    file_picker([visibility_class], model.timer == Opening, GotFile),
    html.ul([class(scoped("menu")), visibility_class], [
      html.li([], [
        menu_item([menu_item_index(0), visibility_class], [text("Config")]),
      ]),
      html.li([], [
        menu_item([menu_item_index(1), visibility_class], [text("About")]),
      ]),
      html.li([], [
        menu_item([menu_item_index(2), visibility_class], [text("Help")]),
      ]),
    ]),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    menu_scene(model),
    case model.timer {
      Opened(sub_model) -> player.view(sub_model) |> element.map(PlayerMsg)

      _ -> html.div([], [])
    },
  ])
}

// STORYBOOK

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  use engine <- ptimer.new_engine()
  let assert Ok(engine) = engine

  let #(player_model, player_effect) =
    player.init(
      ptimer.Ptimer(
        ..ptimer.empty,
        metadata: metadata.Metadata(
          version: "1.0",
          title: "Sample Timer",
          description: Some("Description"),
          lang: "en-US",
        ),
        steps: [
          step.Step(
            id: 0,
            title: "Sample Step",
            description: Some("Step Description"),
            sound: None,
            action: step.UserAction,
          ),
        ],
      ),
    )

  let state =
    flags
    |> dynamic.field("state", dynamic.string)
    |> result.map(fn(state) {
      case state {
        "not_selected" -> NotSelected
        "opening" -> Opening
        "failed_to_open" -> FailedToOpen(ptimer.SchemaViolation)
        "opened" -> Opened(player_model)
        _ -> NotSelected
      }
    })
    |> result.unwrap(NotSelected)

  let story_update = fn(model: Model, msg: Msg) {
    action("update", dynamic.from(msg))

    update(model, msg)
  }

  let _ =
    lustre.application(
      fn(_) {
        #(Model(engine:, timer: state), effect.map(player_effect, PlayerMsg))
      },
      story_update,
      view,
    )
    |> lustre.start(selector, Nil)

  Nil
}
