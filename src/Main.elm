-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Main exposing (main)

import Browser
import Core.Menu as Menu
import Core.Preferences as Preferences
import Core.Session as Session
import Html exposing (div, input, label, p, text)
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode
import Player
import Ptimer.Parser
import Ptimer.Ptimer as Ptimer
import UI.DropZone as DropZone



-- MAIN


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- FLAGS


type alias Flags =
    ()



-- MODEL


type TimerFileLoading
    = NotSelected
    | Loading
    | FailedToLoad String
    | Loaded Player.Model


type DragState
    = NotDragging
    | Dragging


type alias Model =
    { file : TimerFileLoading
    , dragging : DragState
    , session : Session.Session
    , preferences : Preferences.Model
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    let
        ( session, sessionCmd ) =
            Session.init

        ( preferences, preferencesCmd ) =
            Preferences.init
    in
    ( { file = NotSelected
      , dragging = NotDragging
      , session = session
      , preferences = preferences
      }
    , Cmd.batch
        [ Cmd.map SessionMsg sessionCmd
        , Cmd.map PreferencesMsg preferencesCmd
        ]
    )



-- UPDATE


type Msg
    = SelectFile Json.Decode.Value
    | GotPtimerFile Ptimer.PtimerFile
    | GotFileParseError String
    | NoOp
    | DragEnter
    | DragLeave
    | PlayerMsg Player.Msg
    | SessionMsg Session.Msg
    | PreferencesMsg Preferences.Msg
    | MenuMsg Menu.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectFile file ->
            case model.file of
                Loading ->
                    ( model, Cmd.none )

                _ ->
                    ( { model | file = Loading, dragging = NotDragging }, Ptimer.Parser.request file )

        GotPtimerFile file ->
            Player.init file
                |> Tuple.mapBoth
                    (\player -> { model | file = Loaded player })
                    (Cmd.map PlayerMsg)

        GotFileParseError error ->
            ( { model | file = FailedToLoad error }, Cmd.none )

        DragEnter ->
            ( { model | dragging = Dragging }, Cmd.none )

        DragLeave ->
            ( { model | dragging = NotDragging }, Cmd.none )

        PlayerMsg subMsg ->
            case model.file of
                Loaded playerModel ->
                    Player.update model.preferences subMsg playerModel
                        |> Tuple.mapBoth
                            (\player -> { model | file = Loaded player })
                            (Cmd.map PlayerMsg)

                _ ->
                    ( model, Cmd.none )

        SessionMsg subMsg ->
            Session.update subMsg model.session
                |> Tuple.mapBoth
                    (\session -> { model | session = session })
                    (Cmd.map SessionMsg)

        PreferencesMsg subMsg ->
            Preferences.update subMsg model.preferences
                |> Tuple.mapBoth
                    (\preferences -> { model | preferences = preferences })
                    (Cmd.map PreferencesMsg)

        MenuMsg (Menu.SessionMsg subMsg) ->
            update (SessionMsg subMsg) model

        MenuMsg (Menu.PreferencesMsg subMsg) ->
            update (PreferencesMsg subMsg) model

        NoOp ->
            ( model, Cmd.none )



-- VIEW


fileDecoder : Json.Decode.Decoder Json.Decode.Value
fileDecoder =
    Json.Decode.at
        [ "currentTarget", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


filePickerScene : Bool -> List (Html.Html Msg) -> Html.Html Msg
filePickerScene disabled children =
    div
        [ class "main--file-picker-scene" ]
        [ div [ class "main--file-picker-scene--slot" ] children
        , label
            [ class "shared--button" ]
            [ input
                [ Html.Attributes.type_ "file"
                , Html.Events.on
                    "change"
                    (Json.Decode.map SelectFile fileDecoder)
                , Html.Attributes.disabled disabled
                ]
                []
            , text "Open .ptimer file"
            ]
        ]


view : Model -> Browser.Document Msg
view { file, dragging, session, preferences } =
    { title = "Timer (web)"
    , body =
        [ case file of
            NotSelected ->
                filePickerScene False []

            Loading ->
                filePickerScene
                    True
                    [ p [ class "main--loading" ] [ text "Loading timer file..." ]
                    ]

            FailedToLoad details ->
                filePickerScene
                    False
                    [ div [ class "main--load-error" ]
                        [ p [] [ text "Failed to load timer file" ]
                        , Html.pre [] [ text details ]
                        ]
                    ]

            Loaded playerModel ->
                Html.map PlayerMsg (Player.view playerModel)
        , case dragging of
            Dragging ->
                DropZone.view
                    [ DropZone.onDragLeave DragLeave
                    , DropZone.onDrop SelectFile
                    ]
                    [ text "Drop .ptimer file to open" ]

            NotDragging ->
                text ""
        , Menu.view session preferences |> Html.map MenuMsg
        ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.file of
            Loading ->
                Ptimer.Parser.onReceiveParseResult
                    (\result ->
                        case result of
                            Ok file ->
                                GotPtimerFile file

                            Err (Ptimer.Parser.DecodeError error) ->
                                GotFileParseError (Json.Decode.errorToString error)

                            Err (Ptimer.Parser.FormatError error) ->
                                GotFileParseError error
                    )

            Loaded playerModel ->
                Sub.batch
                    [ DropZone.onDragEnter DragEnter
                    , Player.subscriptions playerModel |> Sub.map PlayerMsg
                    ]

            _ ->
                DropZone.onDragEnter DragEnter
        , Session.subscriptions model.session |> Sub.map SessionMsg
        , Preferences.subscriptions model.preferences |> Sub.map PreferencesMsg
        ]
