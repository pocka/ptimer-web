-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module Main exposing (main)

import Browser
import Html exposing (div, input, label, p, text)
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode
import Player
import Ptimer.Ptimer as Ptimer



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



-- PORTS


port sendSelectedFile : Json.Decode.Value -> Cmd msg


port receiveParsedFile : (Json.Decode.Value -> msg) -> Sub msg


port receiveFileParseError : (String -> msg) -> Sub msg


port receiveDragEnter : (Json.Decode.Value -> msg) -> Sub msg



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
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { file = NotSelected, dragging = NotDragging }, Cmd.none )



-- UPDATE


type Msg
    = SelectFile Json.Decode.Value
    | GotPtimerFile Ptimer.PtimerFile
    | GotFileParseError String
    | NoOp
    | DragEnter
    | DragLeave
    | PlayerMsg Player.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectFile file ->
            case model.file of
                Loading ->
                    ( model, Cmd.none )

                _ ->
                    ( { model | file = Loading, dragging = NotDragging }, sendSelectedFile file )

        GotPtimerFile file ->
            let
                ( playerModel, playerCmd ) =
                    Player.init file
            in
            ( { model | file = Loaded playerModel }, Cmd.map PlayerMsg playerCmd )

        GotFileParseError error ->
            ( { model | file = FailedToLoad error }, Cmd.none )

        DragEnter ->
            ( { model | dragging = Dragging }, Cmd.none )

        DragLeave ->
            ( { model | dragging = NotDragging }, Cmd.none )

        PlayerMsg subMsg ->
            case model.file of
                Loaded playerModel ->
                    let
                        ( nextModel, cmd ) =
                            Player.update subMsg playerModel
                    in
                    ( { model | file = Loaded nextModel }, Cmd.map PlayerMsg cmd )

                _ ->
                    ( model, Cmd.none )

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
            [ class "main--button" ]
            [ input
                [ class "main--file-picker--input"
                , Html.Attributes.type_ "file"
                , Html.Events.on
                    "change"
                    (Json.Decode.map SelectFile fileDecoder)
                , Html.Attributes.disabled disabled
                ]
                []
            , text "Open .ptimer file"
            ]
        ]


dropOverlay : List (Html.Attribute msg) -> Html.Html msg
dropOverlay attrs =
    div
        (class "main--drop-overlay" :: attrs)
        [ Html.node "lucide-upload" [ class "main--drop-overlay--icon" ] []
        , p [ class "main--drop-overlay--desc" ] [ text "Drop .ptimer file to open" ]
        ]


dropDecoder : Json.Decode.Decoder Json.Decode.Value
dropDecoder =
    Json.Decode.at [ "dataTransfer", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


view : Model -> Browser.Document Msg
view { file, dragging } =
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
                dropOverlay
                    [ Html.Events.preventDefaultOn "dragleave" (Json.Decode.succeed ( DragLeave, True ))
                    , Html.Events.preventDefaultOn "drop" (Json.Decode.map (\value -> ( SelectFile value, True )) dropDecoder)
                    ]

            NotDragging ->
                text ""
        ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.file of
        Loading ->
            Sub.batch
                [ receiveParsedFile
                    (\value ->
                        case Json.Decode.decodeValue Ptimer.decoder value of
                            Ok file ->
                                GotPtimerFile file

                            Err error ->
                                GotFileParseError (Json.Decode.errorToString error)
                    )
                , receiveFileParseError GotFileParseError
                ]

        Loaded playerModel ->
            Sub.batch [ receiveDragEnter (\_ -> DragEnter), Player.subscriptions playerModel |> Sub.map PlayerMsg ]

        _ ->
            Sub.batch
                [ receiveDragEnter (\_ -> DragEnter)
                ]
