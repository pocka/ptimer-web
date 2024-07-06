-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module Player.Preferences exposing (AudioMuteState(..), Model, Msg(..), init, subscriptions, update)

import Json.Decode as JD
import Json.Encode as JE



-- PORTS


port requestSavePreferences : JD.Value -> Cmd msg


port requestLoadPreferences : () -> Cmd msg


port receiveSavedPreferences : (JD.Value -> msg) -> Sub msg



-- MODEL


type AudioMuteState
    = Muted
    | Unmuted


encodeAudioMuteState : AudioMuteState -> JE.Value
encodeAudioMuteState state =
    case state of
        Muted ->
            JE.int 0

        Unmuted ->
            JE.int 1


audioMuteStateDecoder : JD.Decoder AudioMuteState
audioMuteStateDecoder =
    JD.int
        |> JD.andThen
            (\n ->
                case n of
                    0 ->
                        JD.succeed Muted

                    1 ->
                        JD.succeed Unmuted

                    _ ->
                        JD.fail ("Illigal mute state: " ++ String.fromInt n)
            )


type alias Preferences =
    { audio : AudioMuteState }


encode : Preferences -> JE.Value
encode pref =
    JE.object
        [ ( "audio", encodeAudioMuteState pref.audio ) ]


decoder : JD.Decoder Preferences
decoder =
    JD.map
        Preferences
        (JD.field "audio" audioMuteStateDecoder)


type alias Model =
    { value : Preferences
    , restoreError : Maybe JD.Error
    }


init : ( Model, Cmd Msg )
init =
    ( { value = { audio = Muted }
      , restoreError = Nothing
      }
    , requestLoadPreferences ()
    )



-- UPDATE


type Msg
    = Mute
    | Unmute
    | Save
    | Restore Preferences
    | GotRestoreError JD.Error


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Mute ->
            update Save { model | value = { audio = Muted } }

        Unmute ->
            update Save { model | value = { audio = Unmuted } }

        Save ->
            ( model, requestSavePreferences (encode model.value) )

        Restore value ->
            ( { model | value = value, restoreError = Nothing }, Cmd.none )

        GotRestoreError error ->
            ( { model | restoreError = Just error }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    receiveSavedPreferences
        (\value ->
            case JD.decodeValue decoder value of
                Ok preferences ->
                    Restore preferences

                Err error ->
                    GotRestoreError error
        )
