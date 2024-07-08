-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module BuilderApp.Main exposing (main)

import Browser
import BuilderApp.Builder as Builder
import Html
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode
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



-- PORTS


port builderRequestInitializingFileLoader : () -> Cmd msg


port builderReceiveFileLoaderInitializeError : (String -> msg) -> Sub msg


port builderReceiveFileLoader : (() -> msg) -> Sub msg


port sendSelectedFile : Json.Decode.Value -> Cmd msg



-- MODEL


type FileLoader
    = Loading
    | FailedToLoad String
    | Loaded


type DragState
    = NotDragging
    | Dragging


type alias Model =
    { fileLoader : FileLoader
    , dragging : DragState
    , builder : Maybe Builder.Model
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { fileLoader = Loading, dragging = NotDragging, builder = Nothing }
    , builderRequestInitializingFileLoader ()
    )



-- UPDATE


type Msg
    = NoOp
    | GotFileLoaderInitError String
    | GotFileLoader
    | BuilderMsg Builder.Msg
    | GotPtimerFile Ptimer.PtimerFile
    | SelectFile Json.Decode.Value
    | CreateNew
    | DragEnter
    | DragLeave


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotFileLoaderInitError message ->
            ( { model | fileLoader = FailedToLoad message }, Cmd.none )

        GotFileLoader ->
            ( { model | fileLoader = Loaded }, Cmd.none )

        BuilderMsg subMsg ->
            case model.builder of
                Just subModel ->
                    Builder.update subMsg subModel
                        |> Tuple.mapBoth
                            (\builder -> { model | builder = Just builder })
                            (Cmd.map BuilderMsg)

                Nothing ->
                    ( model, Cmd.none )

        GotPtimerFile file ->
            Builder.init file
                |> Tuple.mapBoth
                    (\builder -> { model | builder = Just builder })
                    (Cmd.map BuilderMsg)

        SelectFile file ->
            ( { model | dragging = NotDragging }, Ptimer.Parser.request file )

        CreateNew ->
            Builder.init Ptimer.new
                |> Tuple.mapBoth
                    (\builder -> { model | builder = Just builder })
                    (Cmd.map BuilderMsg)

        DragEnter ->
            ( { model | dragging = Dragging }, Cmd.none )

        DragLeave ->
            ( { model | dragging = NotDragging }, Cmd.none )



-- VIEW


fileDecoder : Json.Decode.Decoder Json.Decode.Value
fileDecoder =
    Json.Decode.at
        [ "currentTarget", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


view : Model -> Browser.Document Msg
view model =
    { title = ".ptimer file builder"
    , body =
        [ case model.builder of
            Just builder ->
                Builder.view builder |> Html.map BuilderMsg

            Nothing ->
                Html.div [ class "builder--layout" ]
                    [ Html.button
                        [ class "shared--button"
                        , Html.Events.onClick CreateNew
                        ]
                        [ Html.text "Create new timer" ]
                    , Html.label
                        [ class "shared--button" ]
                        [ Html.input
                            [ Html.Attributes.type_ "file"
                            , Html.Events.on
                                "change"
                                (Json.Decode.map SelectFile fileDecoder)
                            ]
                            []
                        , Html.text "Open .ptimer file"
                        ]
                    ]
        , case model.dragging of
            Dragging ->
                DropZone.view
                    [ DropZone.onDragLeave DragLeave
                    , DropZone.onDrop SelectFile
                    ]
                    [ Html.text "Drop .ptimer file to open" ]

            NotDragging ->
                Html.text ""
        ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ builderReceiveFileLoader (\() -> GotFileLoader)
        , builderReceiveFileLoaderInitializeError GotFileLoaderInitError
        , case model.fileLoader of
            Loaded ->
                Ptimer.Parser.onReceiveParseResult
                    (\result ->
                        case result of
                            Ok file ->
                                GotPtimerFile file

                            _ ->
                                NoOp
                    )

            _ ->
                Sub.none
        , case model.builder of
            Just builder ->
                Builder.subscriptions builder |> Sub.map BuilderMsg

            Nothing ->
                DropZone.onDragEnter DragEnter
        ]
