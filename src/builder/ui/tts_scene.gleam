// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/log
import builder/lucide
import builder/tts
import builder/ui/button
import builder/ui/field
import builder/ui/placeholder
import builder/ui/selectbox
import builder/ui/textbox
import gleam/dict
import gleam/dynamic
import gleam/function
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute.{type Attribute, class}
import lustre/effect
import lustre/element.{type Element, text}
import lustre/element/html
import ptimer/asset
import ptimer/object_url
import storybook

// MODEL

type Job {
  Idle
  Running(text: String, voice: tts.Voice)
  RunFailed(tts.RunError)
}

type Speech {
  Speech(url: object_url.ObjectUrl, text: String, voice: tts.Voice)
}

type SceneState {
  SceneState(
    voices: List(#(String, List(tts.Voice))),
    text: String,
    voice: tts.Voice,
    job: Job,
    generated: List(Speech),
    playing: Option(Speech),
  )
}

pub opaque type Model {
  NotLoaded
  LoadingEngine
  LoadingVoiceList(engine: tts.TTS)
  FailedToLoadEngine(error: tts.TTSLoadError)
  FailedToLoadVoiceList(engine: tts.TTS, error: tts.ListVoiceError)
  NoAvailableVoices(engine: tts.TTS)
  Loaded(engine: tts.TTS, voice_list: List(tts.Voice), state: SceneState)
}

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(NotLoaded, effect.none())
}

// UPDATE

pub opaque type InternalMsg {
  Load
  LoadVoiceList(tts.TTS)
  ReceiveEngine(tts.TTS)
  ReceiveEngineLoadError(tts.TTSLoadError)
  ReceiveVoiceList(List(tts.Voice))
  ReceiveVoiceListLoadError(tts.ListVoiceError)
  SetText(String)
  SetLang(String)
  SetVoice(tts.Voice)
  Generate
  ReceiveAudioData(url: object_url.ObjectUrl, text: String, voice: tts.Voice)
  ReceiveRunError(error: tts.RunError, text: String, voice: tts.Voice)
  PlayAudio(speech: Speech)
  StopAudio(speech: Speech)
  DeleteGenerated(speech: Speech)
  AddSpeechAsAsset(speech: Speech)
}

pub type Msg {
  Log(action: log.Action, severity: log.Severity)
  AddAsset(fn(Int) -> asset.Asset)
  Internal(InternalMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg, model {
    Internal(Load), _ -> #(
      LoadingEngine,
      effect.batch([load_engine(), log(log.TTSLoadStart, log.Debug)]),
    )

    Internal(LoadVoiceList(engine)), _ -> #(
      LoadingVoiceList(engine),
      effect.batch([
        load_voice_list(engine),
        log(log.TTSRequestedVoiceList, log.Debug),
      ]),
    )

    Internal(ReceiveEngine(engine)), _ -> #(
      model,
      effect.batch([
        log(log.TTSLoaded, log.Info),
        effect.from(fn(dispatch) { dispatch(Internal(LoadVoiceList(engine))) }),
      ]),
    )

    Internal(ReceiveEngineLoadError(err)), _ -> #(
      FailedToLoadEngine(err),
      log(log.TTSLoadingFailure(err), log.Danger),
    )

    Internal(ReceiveVoiceList(voice_list)), LoadingVoiceList(engine) -> {
      case voice_list {
        [head, ..] -> {
          let voice_grouped =
            voice_list
            |> list.sort(by: fn(a, b) { string.compare(a.name, b.name) })
            |> list.group(by: fn(voice) { voice.lang })
            |> dict.to_list
            |> list.sort(by: fn(a, b) { string.compare(a.0, b.0) })

          #(
            Loaded(
              engine,
              voice_list,
              SceneState(
                voices: voice_grouped,
                text: "",
                voice: head,
                job: Idle,
                generated: [],
                playing: None,
              ),
            ),
            log(log.TTSGotVoiceList(list.length(voice_list)), log.Info),
          )
        }

        [] -> #(NoAvailableVoices(engine), effect.none())
      }
    }

    Internal(ReceiveVoiceListLoadError(err)), LoadingVoiceList(engine) -> #(
      FailedToLoadVoiceList(engine, err),
      log(log.TTSListVoiceFailure(err), log.Danger),
    )

    Internal(SetText(text)),
      Loaded(state: state, engine: engine, voice_list: voice_list)
    -> #(
      Loaded(engine:, voice_list:, state: SceneState(..state, text: text)),
      effect.none(),
    )

    Internal(SetLang(lang)),
      Loaded(state: state, engine: engine, voice_list: voice_list)
    -> #(
      case state.voices |> list.find(fn(voice) { voice.0 == lang }) {
        Ok(#(_, [head, ..])) ->
          Loaded(engine:, voice_list:, state: SceneState(..state, voice: head))
        _ -> model
      },
      effect.none(),
    )

    Internal(SetVoice(voice)),
      Loaded(state: state, engine: engine, voice_list: voice_list)
    -> #(
      Loaded(engine:, voice_list:, state: SceneState(..state, voice:)),
      effect.none(),
    )

    Internal(Generate),
      Loaded(state: state, engine: engine, voice_list: voice_list)
    -> {
      case state.job, state.text {
        Running(_, _), _ -> #(model, effect.none())
        _, "" -> #(model, effect.none())
        _, _ -> #(
          Loaded(
            engine:,
            voice_list:,
            state: SceneState(..state, job: Running(state.text, state.voice)),
          ),
          do_generate(engine, state.text, state.voice),
        )
      }
    }

    Internal(ReceiveAudioData(url, text, voice)),
      Loaded(state:, engine:, voice_list:)
    -> #(
      Loaded(
        engine:,
        voice_list:,
        state: SceneState(
          ..state,
          job: Idle,
          generated: [Speech(url, text, voice), ..state.generated],
        ),
      ),
      effect.none(),
    )

    Internal(ReceiveRunError(err, _text, _voice)),
      Loaded(state:, engine:, voice_list:)
    -> #(
      Loaded(
        engine:,
        voice_list:,
        state: SceneState(..state, job: RunFailed(err)),
      ),
      effect.none(),
    )

    Internal(PlayAudio(speech)), Loaded(state:, engine:, voice_list:) -> #(
      Loaded(
        engine:,
        voice_list:,
        state: SceneState(..state, playing: Some(speech)),
      ),
      effect.batch([
        case state.playing {
          Some(prev) -> do_stop(prev)
          None -> effect.none()
        },
        do_play(speech),
      ]),
    )

    Internal(StopAudio(speech)),
      Loaded(
        state: SceneState(
          playing: Some(now),
          ..,
        ) as state,
        engine:,
        voice_list:,
      )
      if speech == now
    -> #(
      Loaded(engine:, voice_list:, state: SceneState(..state, playing: None)),
      do_stop(now),
    )

    Internal(DeleteGenerated(speech)), Loaded(state:, engine:, voice_list:) -> #(
      Loaded(
        engine:,
        voice_list:,
        state: SceneState(
          ..state,
          generated: state.generated |> list.filter(fn(x) { x != speech }),
        ),
      ),
      release_speech(speech),
    )

    Internal(AddSpeechAsAsset(speech)), Loaded(state:, engine:, voice_list:) -> #(
      Loaded(
        engine:,
        voice_list:,
        state: SceneState(
          ..state,
          generated: state.generated |> list.filter(fn(x) { x != speech }),
        ),
      ),
      effect.from(fn(dispatch) {
        dispatch(
          AddAsset(asset.Asset(
            id: _,
            name: speech.text,
            mime: "audio/wav",
            notice: Some(
              "Generated by TTS feature. Text: \""
              <> speech.text
              <> "\", Voice: "
              <> speech.voice.name,
            ),
            url: speech.url |> object_url.to_string,
          )),
        )
      }),
    )

    _, _ -> #(model, effect.none())
  }
}

// EFFECTS

fn load_engine() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use engine <- tts.new_tts()

    dispatch(
      Internal(case engine {
        Ok(engine) -> ReceiveEngine(engine)
        Error(err) -> ReceiveEngineLoadError(err)
      }),
    )
  })
}

fn load_voice_list(engine: tts.TTS) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use voice_list <- tts.list_voices(engine)

    dispatch(
      Internal(case voice_list {
        Ok(voice_list) -> ReceiveVoiceList(voice_list)
        Error(err) -> ReceiveVoiceListLoadError(err)
      }),
    )
  })
}

fn do_generate(
  engine: tts.TTS,
  text: String,
  voice: tts.Voice,
) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use result <- tts.run(engine, text, voice)

    dispatch(
      Internal(case result {
        Ok(url) -> ReceiveAudioData(url, text, voice)
        Error(err) -> ReceiveRunError(err, text, voice)
      }),
    )
  })
}

fn speech_to_id(speech: Speech) -> String {
  object_url.to_string(speech.url)
}

@external(javascript, "@/builder/ui/tts_scene.ffi.ts", "playAudioEl")
fn play_audio_el(id: String, on_completed: fn() -> Nil) -> Nil

fn do_play(speech: Speech) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    use <- play_audio_el(speech_to_id(speech))

    dispatch(Internal(StopAudio(speech)))
  })
}

@external(javascript, "@/builder/ui/tts_scene.ffi.ts", "stopAudioEl")
fn stop_audio_el(id: String) -> Nil

fn do_stop(speech: Speech) -> effect.Effect(Msg) {
  effect.from(fn(_dispatch) { stop_audio_el(speech_to_id(speech)) })
}

fn release_speech(speech: Speech) -> effect.Effect(Msg) {
  effect.from(fn(_dispatch) { object_url.revoke(speech.url) })
}

fn log(action: log.Action, severity: log.Severity) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(Log(action, severity)) })
}

// VIEW

@external(javascript, "@/builder/ui/tts_scene.ffi.ts", "className")
fn scoped(x: String) -> String

fn with_tts(
  msg: fn(Msg) -> msg,
  model: Model,
  attrs: List(Attribute(msg)),
  callback: fn(tts.TTS, List(tts.Voice), SceneState) -> Element(msg),
) -> Element(msg) {
  html.div([class(scoped("container")), ..attrs], [
    case model {
      Loaded(engine, voice_list, state) -> callback(engine, voice_list, state)
      _ ->
        placeholder.view(
          title: [text("Text-to-Speech")],
          description: [
            html.div([class(scoped("placeholder-description"))], [
              html.p([], [
                text(
                  "Text-to-Speech (TTS) feature downloads Machine Learning models from third-party service
                then generates speech audio data on your browser using the downloaded models.
              ",
                ),
              ]),
              html.ul([class(scoped("placeholder-list"))], [
                html.li([], [
                  text(
                    "You can't use this feature without internet connection.",
                  ),
                ]),
                html.li([], [
                  text(
                    "Changes or disruption to the third-party service may render this feature unavailable.",
                  ),
                ]),
                html.li([], [
                  text(
                    "Output quality and consistency are not guaranteed, as the models are outside the control of this application.",
                  ),
                ]),
              ]),
              html.p([], [text("Use this feature at your own risk.")]),
              case model {
                FailedToLoadEngine(err) ->
                  html.p([class(scoped("placeholder-error"))], [
                    text("Failed to load TTS engine: "),
                    text(tts.tts_load_error_to_string(err)),
                  ])
                FailedToLoadVoiceList(_, err) ->
                  html.p([class(scoped("placeholder-error"))], [
                    text("Failed to load TTS voice list: "),
                    text(tts.list_voice_error_to_string(err)),
                  ])
                NoAvailableVoices(_) ->
                  html.p([class(scoped("placeholder-error"))], [
                    text("Got an empty list of voice data."),
                  ])
                _ -> element.none()
              },
            ]),
          ],
          actions: [
            case model {
              FailedToLoadEngine(_) ->
                button.new(button.Button(Internal(Load) |> msg))
                |> button.variant(button.Primary)
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Retry")])
              FailedToLoadVoiceList(engine, _) ->
                button.new(button.Button(Internal(LoadVoiceList(engine)) |> msg))
                |> button.variant(button.Primary)
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Retry")])
              LoadingEngine ->
                button.new(button.NoOp)
                |> button.variant(button.Primary)
                |> button.state(button.Loading(None))
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Loading")])
              LoadingVoiceList(_) ->
                button.new(button.NoOp)
                |> button.variant(button.Primary)
                |> button.state(button.Loading(None))
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Loading")])
              NoAvailableVoices(engine) ->
                button.new(button.Button(Internal(LoadVoiceList(engine)) |> msg))
                |> button.variant(button.Primary)
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Reload")])
              _ ->
                button.new(button.Button(Internal(Load) |> msg))
                |> button.variant(button.Primary)
                |> button.icon(lucide.Globe)
                |> button.view([], [text("Activate")])
            },
          ],
          attrs: [],
        )
    },
  ])
}

pub fn view(
  msg: fn(Msg) -> msg,
  model: Model,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  use _engine, voice_list, scene <- with_tts(msg, model, attrs)

  html.div([class(scoped("scene"))], [
    html.div([class(scoped("form"))], [
      field.new("tts_text", {
        textbox.textbox(
          scene.text,
          textbox.Enabled(fn(str) { str |> SetText |> Internal |> msg }),
          textbox.SingleLine,
          _,
        )
      })
        |> field.label([text("Text")])
        |> field.note([text("Speech text.")])
        |> field.view([]),
      html.div([class(scoped("voice-fields"))], [
        field.new("tts_lang", {
          selectbox.selectbox(
            scene.voice.lang,
            scene.voices
              |> list.map(fn(pair) {
                let #(lang, _) = pair
                selectbox.Option(id: lang, label: lang, value: lang)
              }),
            selectbox.Enabled(fn(lang) { lang |> SetLang |> Internal |> msg }),
            _,
            [],
          )
        })
          |> field.label([text("Language")])
          |> field.view([]),
        field.new("tts_voice", {
          selectbox.selectbox(
            scene.voice,
            voice_list
              |> list.filter_map(fn(voice) {
                case voice.lang == scene.voice.lang {
                  True ->
                    Ok(selectbox.Option(
                      id: tts.voice_id(voice),
                      label: voice.name,
                      value: voice,
                    ))
                  False -> Error(Nil)
                }
              }),
            selectbox.Enabled(fn(voice) { voice |> SetVoice |> Internal |> msg }),
            _,
            [],
          )
        })
          |> field.label([text("Voice")])
          |> field.view([class(scoped("voice"))]),
      ]),
      // TODO: Display dataset/model copyright, license and URL for selected voice.
    ]),
    button.new(button.Button(Generate |> Internal |> msg))
      |> button.state(case scene.job, scene.text {
        Running(_, _), _ -> button.Loading(None)
        _, "" -> button.Disabled(None)
        _, _ -> button.Enabled
      })
      |> button.variant(button.Primary)
      |> button.view([], [text("Generate")]),
    case scene.job {
      Running(speech_text, voice) ->
        html.p([class(scoped("running"))], [
          text("Generating speech audio from \""),
          text(speech_text),
          text("\" using "),
          text(voice.name),
          text(" voice..."),
        ])

      RunFailed(err) ->
        html.p([class(scoped("run-failed"))], [
          text("Failed to generate speech audio: "),
          text(tts.run_error_to_string(err)),
        ])

      _ -> element.none()
    },
    element.keyed(html.ul([class(scoped("generated-list"))], _), {
      use speech <- list.map(scene.generated)

      let id = speech_to_id(speech)

      #(
        id,
        html.li([class(scoped("generated"))], [
          html.audio([attribute.id(id)], [
            html.source([speech.url |> object_url.to_string |> attribute.src]),
          ]),
          html.div([class(scoped("generated-field"))], [
            html.span([class(scoped("generated-label"))], [text("Text")]),
            html.span([], [text(speech.text)]),
          ]),
          html.div([class(scoped("generated-field"))], [
            html.span([class(scoped("generated-label"))], [text("Voice")]),
            html.span([], [
              text(speech.voice.name),
              text(" ("),
              text(speech.voice.lang),
              text(")"),
            ]),
          ]),
          html.div([class(scoped("generated-actions"))], [
            case scene.playing == Some(speech) {
              True ->
                button.new(button.Button(speech |> StopAudio |> Internal |> msg))
                |> button.size(button.Small)
                |> button.icon(lucide.Square)
                |> button.view([], [element.text("Stop")])
              False ->
                button.new(button.Button(speech |> PlayAudio |> Internal |> msg))
                |> button.size(button.Small)
                |> button.icon(lucide.Play)
                |> button.view([], [element.text("Play")])
            },
            button.new(button.Button(
              speech |> AddSpeechAsAsset |> Internal |> msg,
            ))
              |> button.size(button.Small)
              |> button.icon(lucide.ListPlus)
              |> button.view([], [element.text("Move to assets")]),
            button.new(button.Button(
              speech |> DeleteGenerated |> Internal |> msg,
            ))
              |> button.size(button.Small)
              |> button.icon(lucide.Trash2)
              |> button.view([], [element.text("Delete")]),
          ]),
        ]),
      )
    }),
  ])
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let model: Model = case flags |> dynamic.field("state", dynamic.string) {
    Ok("loading") -> LoadingEngine
    Ok("failed_to_load") -> FailedToLoadEngine(tts.TTSLoadError("Sample Error"))
    _ -> NotLoaded
  }

  let _ =
    lustre.application(
      fn(_flags) { #(model, effect.none()) },
      fn(model, msg) {
        action("update", dynamic.from(msg))

        update(model, msg)
      },
      view(function.identity, _, []),
    )
    |> lustre.start(selector, Nil)

  Nil
}
