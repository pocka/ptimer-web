-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module Main exposing (main)

import Browser
import Html exposing (audio, div, input, li, p, text, ul)
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode
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
    | Loaded Ptimer.PtimerFile


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
            ( { model | file = Loaded file }, Cmd.none )

        GotFileParseError error ->
            ( { model | file = FailedToLoad error }, Cmd.none )

        DragEnter ->
            ( { model | dragging = Dragging }, Cmd.none )

        DragLeave ->
            ( { model | dragging = NotDragging }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- VIEW


fileDecoder : Json.Decode.Decoder Json.Decode.Value
fileDecoder =
    Json.Decode.at
        [ "currentTarget", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


dropOverlay : List (Html.Attribute msg) -> Html.Html msg
dropOverlay attrs =
    div
        (class "main--drop-overlay" :: attrs)
        [ p [] [ text "Drop .ptimer file to open" ] ]


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
                input
                    [ Html.Attributes.type_ "file"
                    , Html.Events.on
                        "change"
                        (Json.Decode.map SelectFile fileDecoder)
                    ]
                    []

            Loading ->
                p [] [ text "Loading timer file" ]

            FailedToLoad details ->
                p []
                    [ text "Failed to load timer file: "
                    , text details
                    ]

            Loaded { metadata, steps, assets } ->
                div []
                    [ p [] [ text metadata.title ]
                    , ul []
                        (steps
                            |> List.map
                                (\step ->
                                    li [] [ text step.title ]
                                )
                        )
                    , ul []
                        (assets
                            |> List.map
                                (\asset ->
                                    li []
                                        [ audio
                                            [ Html.Attributes.src asset.url
                                            , Html.Attributes.controls True
                                            ]
                                            []
                                        ]
                                )
                        )
                    ]
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

        _ ->
            Sub.batch
                [ receiveDragEnter (\_ -> DragEnter)
                ]
