-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module Main exposing (main)

import Browser
import Html exposing (audio, div, input, label, li, p, span, text, ul)
import Html.Attributes
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



-- MODEL


type TimerFileLoading
    = NotSelected
    | Loading
    | FailedToLoad String
    | Loaded Ptimer.PtimerFile


type alias Model =
    { file : TimerFileLoading
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { file = NotSelected }, Cmd.none )



-- UPDATE


type Msg
    = SelectFile Json.Decode.Value
    | GotPtimerFile Ptimer.PtimerFile
    | GotFileParseError String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectFile file ->
            case model.file of
                NotSelected ->
                    ( { model | file = Loading }, sendSelectedFile file )

                Loaded _ ->
                    ( { model | file = Loading }, sendSelectedFile file )

                _ ->
                    ( model, Cmd.none )

        GotPtimerFile file ->
            ( { model | file = Loaded file }, Cmd.none )

        GotFileParseError error ->
            ( { model | file = FailedToLoad error }, Cmd.none )



-- VIEW


fileDecoder : Json.Decode.Decoder Json.Decode.Value
fileDecoder =
    Json.Decode.at
        [ "currentTarget", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


view : Model -> Browser.Document Msg
view { file } =
    { title = "Timer (web)"
    , body =
        [ case file of
            NotSelected ->
                div
                    []
                    [ label []
                        [ span [] [ text "Select or drop timer file here" ]
                        , input
                            [ Html.Attributes.type_ "file"
                            , Html.Events.on
                                "change"
                                (Json.Decode.map SelectFile fileDecoder)
                            ]
                            []
                        ]
                    ]

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
            Sub.none
