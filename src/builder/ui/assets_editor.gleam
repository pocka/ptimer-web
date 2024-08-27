// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/lucide
import builder/ptimer
import builder/ptimer/asset
import builder/ptimer/step
import builder/storybook
import builder/ui/button
import builder/ui/field
import builder/ui/placeholder
import builder/ui/textbox
import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect
import lustre/element
import lustre/element/html

// MODEL

pub opaque type Model {
  Model(now_playing: Option(asset.Asset))
}

pub fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model(None), effect.none())
}

// UPDATE

fn asset_to_playback_id(asset: asset.Asset) -> String {
  "playback__" <> int.to_string(asset.id)
}

pub opaque type InternalMsg {
  Append(assets: List(asset.Asset), file: dynamic.Dynamic)
  Delete(asset: asset.Asset)
  Edit(payload: asset.Asset)
  Play(asset: asset.Asset)
  StopPlayback(asset: asset.Asset)
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

    Internal(Play(asset)) -> #(Model(now_playing: Some(asset)), do_play(asset))

    Internal(StopPlayback(asset)) ->
      case model.now_playing == Some(asset) {
        True -> #(Model(now_playing: None), do_stop(asset))
        False -> #(model, effect.none())
      }

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

@external(javascript, "@/builder/ui/assets_editor.ffi.ts", "playAudioEl")
fn play_audio_el(id: String, on_completed: fn() -> Nil) -> Nil

fn do_play(asset: asset.Asset) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use <- play_audio_el(asset_to_playback_id(asset))

    dispatch(Internal(StopPlayback(asset)))
  })
}

@external(javascript, "@/builder/ui/assets_editor.ffi.ts", "stopAudioEl")
fn stop_audio_el(id: String) -> Nil

fn do_stop(asset: asset.Asset) -> effect.Effect(Msg) {
  effect.from(fn(_dispatch) { stop_audio_el(asset_to_playback_id(asset)) })
}

// VIEW

@external(javascript, "@/builder/ui/assets_editor.ffi.ts", "className")
fn scoped(x: String) -> String

fn audio_player(model: Model, asset: asset.Asset) -> element.Element(Msg) {
  element.fragment([
    html.audio(
      [
        attribute.id(asset_to_playback_id(asset)),
        class(scoped("audio-preview")),
        attribute.controls(False),
      ],
      [html.source([attribute.type_(asset.mime), attribute.src(asset.url)])],
    ),
    case model.now_playing == Some(asset) {
      True ->
        button.new(button.Button(Internal(StopPlayback(asset))))
        |> button.size(button.Small)
        |> button.icon(lucide.Square)
        |> button.view([], [element.text("Stop")])
      False ->
        button.new(button.Button(Internal(Play(asset))))
        |> button.size(button.Small)
        |> button.icon(lucide.Play)
        |> button.view([], [element.text("Play")])
    },
  ])
}

fn list_item(
  msg: fn(Msg) -> msg,
  model: Model,
  asset: asset.Asset,
  err: Option(asset.EncodeError),
) -> element.Element(msg) {
  html.li([class(scoped("item"))], [
    field.new(ptimer.field_to_id(ptimer.Asset(asset.id, asset.Name)), {
      textbox.textbox(
        asset.name,
        textbox.Enabled(fn(str) {
          msg(Internal(Edit(asset.Asset(..asset, name: str))))
        }),
        textbox.SingleLine,
        _,
      )
    })
      |> field.label([element.text("Name")])
      |> field.note([
        element.text(
          "Name of the asset. Give an asset an unique name to dinstinguish easily.",
        ),
      ])
      |> field.validity(case err {
        Some(asset.EncodeError(name: Some(asset.EmptyName), ..)) ->
          field.Invalid([element.text("Asset name can't be empty.")])
        _ -> field.Valid
      })
      |> field.view(attrs: []),
    field.new(ptimer.field_to_id(ptimer.Asset(asset.id, asset.MIME)), {
      textbox.textbox(
        asset.mime,
        textbox.Enabled(fn(str) {
          msg(Internal(Edit(asset.Asset(..asset, mime: str))))
        }),
        textbox.SingleLine,
        _,
      )
    })
      |> field.label([element.text("MIME")])
      |> field.note([
        element.text(
          "File type (MIME) of the asset. Edit only when browser guessed incorrect MIME.",
        ),
      ])
      |> field.validity(case err {
        Some(asset.EncodeError(mime: Some(asset.EmptyMime), ..)) ->
          field.Invalid([
            element.text(
              "File type (MIME) can't be empty. It helps player application to determine which codec to use for media playback.",
            ),
          ])
        Some(asset.EncodeError(mime: Some(asset.MimeNotIncludingSlash), ..)) ->
          field.Invalid([
            element.text(
              "This is not a valid MIME type string. It must contain a \"/\" (slash) character.",
            ),
          ])
        _ -> field.Valid
      })
      |> field.view(attrs: []),
    field.new(ptimer.field_to_id(ptimer.Asset(asset.id, asset.Notice)), {
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
        _,
      )
    })
      |> field.label([element.text("Notice")])
      |> field.note([
        element.text(
          "Piece of text you want to attach to the asset."
          <> " If the asset is a copyright material and you have to include a license text,"
          <> " paste the license text here.",
        ),
      ])
      |> field.view(attrs: []),
    html.div([class(scoped("item-footer"))], [
      case asset.mime {
        "audio/wav" -> audio_player(model, asset) |> element.map(msg)
        "audio/mp3" -> audio_player(model, asset) |> element.map(msg)
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
  model: Model,
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
              model,
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
