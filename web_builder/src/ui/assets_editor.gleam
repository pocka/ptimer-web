// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lucide
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect
import lustre/element
import lustre/element/html
import ptimer
import ptimer/asset
import ptimer/step
import storybook
import ui/button
import ui/field
import ui/placeholder
import ui/textbox

// MODEL

pub opaque type Model {
  Model
}

pub fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model, effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  Append(assets: List(asset.Asset), file: dynamic.Dynamic)
  Delete(asset: asset.Asset)
  Edit(payload: asset.Asset)
  NoOp
}

pub type Msg {
  Update(fn(ptimer.Ptimer) -> ptimer.Ptimer)
  Internal(InternalMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    Update(_) -> #(model, effect.none())

    Internal(Append(assets, file)) -> {
      let max_id =
        assets
        |> list.fold(-1, fn(max, asset) { int.max(max, asset.id) })

      case asset.create(max_id + 1, file) {
        Ok(asset) -> #(
          model,
          chain(
            Update(fn(prev) {
              ptimer.Ptimer(..prev, assets: list.append(prev.assets, [asset]))
            }),
          ),
        )

        _ -> #(model, effect.none())
      }
    }

    Internal(Delete(asset)) -> #(
      model,
      effect.batch([
        chain(
          Update(fn(prev) {
            ptimer.Ptimer(
              ..prev,
              steps: prev.steps
                |> list.map(fn(step) {
                  step.Step(
                    ..step,
                    sound: case step.sound {
                      Some(sound_id) if sound_id == asset.id -> None
                      _ -> step.sound
                    },
                  )
                }),
              assets: prev.assets |> list.filter(fn(x) { asset.id != x.id }),
            )
          }),
        ),
        release(asset),
      ]),
    )

    Internal(Edit(payload)) -> #(
      model,
      chain(
        Update(fn(prev) {
          ptimer.Ptimer(
            ..prev,
            assets: prev.assets
              |> list.map(fn(asset) {
                case asset.id == payload.id {
                  True -> payload
                  False -> asset
                }
              }),
          )
        }),
      ),
    )

    Internal(NoOp) -> #(model, effect.none())
  }
}

// EFFECTS

fn chain(msg: Msg) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(msg) })
}

fn release(asset: asset.Asset) -> effect.Effect(msg) {
  effect.from(fn(_) { asset.release(asset) })
}

// VIEW

@external(javascript, "@/ui/assets_editor.ffi.ts", "className")
fn scoped(x: String) -> String

fn audio_player(asset: asset.Asset) -> element.Element(msg) {
  html.audio([class(scoped("audio-preview")), attribute.controls(True)], [
    html.source([attribute.type_(asset.mime), attribute.src(asset.url)]),
  ])
}

fn list_item(
  msg: fn(Msg) -> msg,
  asset: asset.Asset,
  err: Option(asset.EncodeError),
) -> element.Element(msg) {
  let id = fn(x: String) -> String { int.to_string(asset.id) <> "_" <> x }

  html.li([class(scoped("item"))], [
    field.view(
      id: id("name"),
      label: [element.text("Name")],
      input: fn(attrs) {
        textbox.textbox(
          asset.name,
          textbox.Enabled(fn(str) {
            msg(Internal(Edit(asset.Asset(..asset, name: str))))
          }),
          textbox.SingleLine,
          attrs,
        )
      },
      note: Some(case err {
        Some(asset.EncodeError(name: Some(asset.EmptyName), ..)) -> [
          element.text("Asset name can't be empty."),
        ]
        _ -> [
          element.text(
            "Name of the asset. Give an asset an unique name to dinstinguish easily.",
          ),
        ]
      }),
      attrs: [],
    ),
    field.view(
      id: id("mime"),
      label: [element.text("MIME")],
      input: fn(attrs) {
        textbox.textbox(
          asset.mime,
          textbox.Enabled(fn(str) {
            msg(Internal(Edit(asset.Asset(..asset, mime: str))))
          }),
          textbox.SingleLine,
          attrs,
        )
      },
      note: Some(case err {
        Some(asset.EncodeError(mime: Some(asset.EmptyMime), ..)) -> [
          element.text(
            "File type (MIME) can't be empty. It helps player application to determine which codec to use for media playback.",
          ),
        ]
        Some(asset.EncodeError(mime: Some(asset.MimeNotIncludingSlash), ..)) -> [
          element.text(
            "This is not a valid MIME type string. It must contain a \"/\" (slash) character.",
          ),
        ]
        _ -> [
          element.text(
            "File type (MIME) of the asset. Edit only when browser guessed incorrect MIME.",
          ),
        ]
      }),
      attrs: [],
    ),
    field.view(
      id: id("notice"),
      label: [element.text("Notice")],
      input: fn(attrs) {
        textbox.textbox(
          asset.notice |> option.unwrap(""),
          textbox.Enabled(fn(str) {
            msg(
              Internal(Edit(
                asset.Asset(
                  ..asset,
                  notice: case str {
                    "" -> None
                    str -> Some(str)
                  },
                ),
              )),
            )
          }),
          textbox.MultiLine(Some(3)),
          attrs,
        )
      },
      note: Some([
        element.text(
          "Piece of text you want to attach to the asset."
          <> " If the asset is a copyright material and you have to include a license text,"
          <> " paste the license text here.",
        ),
      ]),
      attrs: [],
    ),
    html.div([class(scoped("item-footer"))], [
      case asset.mime {
        "audio/wav" -> audio_player(asset)
        "audio/mp3" -> audio_player(asset)
        _ -> html.div([], [])
      },
      button.new(button.Button(msg(Internal(Delete(asset)))))
        |> button.size(button.Small)
        |> button.icon(lucide.Trash2)
        |> button.view([], [element.text("Delete")]),
    ]),
  ])
}

pub fn view(
  msg: fn(Msg) -> msg,
  timer: ptimer.Ptimer,
  _model: Model,
  err: dict.Dict(Int, asset.EncodeError),
  attrs: List(Attribute(msg)),
) -> element.Element(msg) {
  case timer.assets {
    [] ->
      placeholder.view(
        title: [element.text("No assets")],
        description: [
          element.text(
            "You can choose steps sound from sound files added here.",
          ),
        ],
        actions: [
          button.new(
            button.FilePicker(
              fn(file) {
                Append(timer.assets, file)
                |> Internal
                |> msg
              },
              ["audio/mp3", "audio/wav"],
            ),
          )
          |> button.variant(button.Primary)
          |> button.icon(lucide.ListPlus)
          |> button.view([], [element.text("Add asset")]),
        ],
        attrs: [],
      )

    assets ->
      html.div([class(scoped("container")), ..attrs], [
        element.keyed(html.ol([class(scoped("list"))], _), {
          use asset <- list.map(assets)

          #(
            int.to_string(asset.id),
            list_item(
              msg,
              asset,
              err |> dict.get(asset.id) |> option.from_result,
            ),
          )
        }),
        button.new(
          button.FilePicker(
            fn(file) {
              Append(timer.assets, file)
              |> Internal
              |> msg
            },
            ["audio/mp3", "audio/wav"],
          ),
        )
          |> button.variant(button.Primary)
          |> button.icon(lucide.ListPlus)
          |> button.view([], [element.text("Add new asset")]),
      ])
  }
}

type StoryModel {
  StoryModel(
    timer: ptimer.Ptimer,
    model: Model,
    encoded: Result(ptimer.Encoded, ptimer.EncodeError),
  )
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let story_update = fn(model: StoryModel, msg: Msg) -> #(
    StoryModel,
    effect.Effect(Msg),
  ) {
    case msg {
      Update(f) -> {
        let after = f(model.timer)
        let #(m, e) = update(model.model, msg)

        action("Update", dynamic.from(after))

        #(StoryModel(after, m, ptimer.encode(after)), e)
      }

      Internal(internal_msg) -> {
        let #(m, e) = update(model.model, msg)

        action("Internal", dynamic.from(internal_msg))

        #(StoryModel(..model, model: m), e)
      }
    }
  }

  let assets: List(asset.Asset) =
    flags
    |> dynamic.field("assets", dynamic.list(dynamic.dynamic))
    |> result.map(fn(values) {
      values
      |> list.index_map(fn(value, i) { asset.create(i, value) })
      |> list.filter_map(function.identity)
    })
    |> result.unwrap([])

  let _ =
    lustre.application(
      fn(_) {
        let timer = ptimer.Ptimer(..ptimer.empty, assets:)
        let #(m, e) = init(Nil)
        #(StoryModel(timer, m, ptimer.encode(timer)), e)
      },
      story_update,
      fn(model) {
        view(
          function.identity,
          model.timer,
          model.model,
          model.encoded
            |> result.map_error(fn(err) { err.assets })
            |> result.unwrap_error(dict.new()),
          [],
        )
      },
    )
    |> lustre.start(selector, Nil)

  Nil
}
