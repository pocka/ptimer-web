-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module BuilderApp.Builder exposing (Model, Msg, init, subscriptions, update, view)

import Html
import Html.Attributes exposing (class, id)
import Html.Events
import Json.Decode
import Platform.Cmd as Cmd
import Ptimer.Ptimer as Ptimer



-- PORTS


port builderBuilderRequestFileUrl : Json.Decode.Value -> Cmd msg


port builderBuilderReceiveFileUrl : (Json.Decode.Value -> msg) -> Sub msg


port builderBuilderRequestReleaseObjectUrl : String -> Cmd msg


port builderBuilderRequestCompile : Json.Decode.Value -> Cmd msg


port builderBuilderReceiveCompiledFile : (String -> msg) -> Sub msg


port builderBuilderReceiveCompileError : (String -> msg) -> Sub msg



-- MODEL


type DragState
    = NotDragging
    | Dragging Ptimer.Step (Maybe Ptimer.Step)


type Compilation
    = Idle
    | Compiling Ptimer.PtimerFile
    | Compiled Ptimer.PtimerFile String


type Error
    = Visible String
    | Dismissed String


type alias Model =
    { file : Ptimer.PtimerFile
    , dragging : DragState
    , compilation : Compilation
    , errors : List Error
    }


init : Ptimer.PtimerFile -> ( Model, Cmd Msg )
init file =
    ( { file = file, dragging = NotDragging, compilation = Idle, errors = [] }
    , Cmd.none
    )



-- UPDATE


type Msg
    = NoOp
    | WriteMetadata (Ptimer.Metadata -> Ptimer.Metadata)
    | WriteSteps (List Ptimer.Step -> List Ptimer.Step)
    | WriteAssets (List Ptimer.Asset -> List Ptimer.Asset)
    | AppendStep
    | RequestFileURL Json.Decode.Value
    | AppendAsset (Ptimer.AssetId -> Ptimer.Asset)
    | DragStart Ptimer.Step
    | DragEnd
    | DragEnter Ptimer.Step
    | DragLeave Ptimer.Step
    | Drop Ptimer.Step
    | DeleteAsset Ptimer.Asset
    | Compile Ptimer.PtimerFile
    | GotCompiledFile String
    | GotCompileError String
    | InvalidateCompiledFile
    | DismissError Int


chain : Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
chain msg ( model, cmd ) =
    update msg model
        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        WriteMetadata f ->
            let
                file =
                    model.file
            in
            ( { model | file = { file | metadata = f file.metadata } }, Cmd.none )
                |> chain InvalidateCompiledFile

        WriteSteps f ->
            let
                file =
                    model.file
            in
            ( { model | file = { file | steps = f file.steps } }, Cmd.none )
                |> chain InvalidateCompiledFile

        WriteAssets f ->
            let
                file =
                    model.file
            in
            ( { model | file = { file | assets = f file.assets } }, Cmd.none )
                |> chain InvalidateCompiledFile

        AppendStep ->
            update (WriteSteps Ptimer.appendStep) model

        RequestFileURL file ->
            ( model, builderBuilderRequestFileUrl file )

        AppendAsset f ->
            update (WriteAssets (Ptimer.appendAsset f)) model

        DragStart step ->
            ( { model | dragging = Dragging step Nothing }, Cmd.none )

        DragEnd ->
            ( { model | dragging = NotDragging }, Cmd.none )

        DragEnter target ->
            case model.dragging of
                Dragging step _ ->
                    if step == target then
                        ( model, Cmd.none )

                    else
                        ( { model | dragging = Dragging step (Just target) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        DragLeave target ->
            case model.dragging of
                Dragging step (Just currentTarget) ->
                    if currentTarget == target then
                        ( { model | dragging = Dragging step Nothing }, Cmd.none )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Drop dst ->
            case model.dragging of
                Dragging src (Just _) ->
                    update
                        (WriteSteps
                            (\steps ->
                                steps
                                    |> List.foldr
                                        (\step ->
                                            \acc ->
                                                if step == src then
                                                    acc

                                                else if step == dst then
                                                    step :: src :: acc

                                                else
                                                    step :: acc
                                        )
                                        []
                            )
                        )
                        { model | dragging = NotDragging }

                _ ->
                    ( { model | dragging = NotDragging }, Cmd.none )

        DeleteAsset asset ->
            let
                file =
                    model.file
            in
            ( { model
                | file =
                    { file
                        | steps =
                            file.steps
                                |> List.map
                                    (\step ->
                                        if step.sound == Just asset.id then
                                            { step | sound = Nothing }

                                        else
                                            step
                                    )
                        , assets = List.filter (\a -> not (a == asset)) file.assets
                    }
              }
            , builderBuilderRequestReleaseObjectUrl asset.url
            )
                |> chain InvalidateCompiledFile

        Compile file ->
            case model.compilation of
                Idle ->
                    ( { model | compilation = Compiling file }, builderBuilderRequestCompile (Ptimer.encode file) )

                _ ->
                    ( model, Cmd.none )

        GotCompiledFile url ->
            case model.compilation of
                Compiling file ->
                    ( { model | compilation = Compiled file url }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotCompileError error ->
            case model.compilation of
                Compiling _ ->
                    ( { model | compilation = Idle, errors = model.errors ++ [ Visible error ] }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        InvalidateCompiledFile ->
            case model.compilation of
                Compiled _ url ->
                    ( { model | compilation = Idle }, builderBuilderRequestReleaseObjectUrl url )

                _ ->
                    ( model, Cmd.none )

        DismissError n ->
            ( { model
                | errors =
                    model.errors
                        |> List.indexedMap
                            (\i ->
                                \error ->
                                    if i == n then
                                        Nothing

                                    else
                                        Just error
                            )
                        |> List.filterMap identity
              }
            , Cmd.none
            )



-- VIEW


fileDecoder : Json.Decode.Decoder Json.Decode.Value
fileDecoder =
    Json.Decode.at
        [ "currentTarget", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


findAsset : String -> List Ptimer.Asset -> Maybe Ptimer.Asset
findAsset id assets =
    case assets of
        [] ->
            Nothing

        x :: xs ->
            if id == Ptimer.assetIdToString x.id then
                Just x

            else
                findAsset id xs


view : Model -> Html.Html Msg
view model =
    Html.form
        [ class "builder--form"
        , Html.Events.onSubmit (Compile model.file)
        ]
        [ Html.div [ class "builder--section" ]
            [ Html.span [ class "builder--section--title" ]
                [ Html.text "Metadata"
                ]
            , Html.div
                [ class "builder--field" ]
                [ Html.label [ Html.Attributes.for "metadata_title" ] [ Html.text "Title" ]
                , Html.input
                    [ Html.Attributes.value model.file.metadata.title
                    , Html.Attributes.id "metadata_title"
                    , Html.Attributes.required True
                    , Html.Events.onInput
                        (\text ->
                            WriteMetadata
                                (\metadata ->
                                    { metadata | title = text }
                                )
                        )
                    ]
                    []
                ]
            , Html.div [ class "builder--field" ]
                [ Html.label [ Html.Attributes.for "metadata_desc" ] [ Html.text "Description" ]
                , Html.input
                    [ Html.Attributes.value (model.file.metadata.description |> Maybe.withDefault "")
                    , Html.Attributes.id "metadata_desc"
                    , Html.Events.onInput
                        (\text ->
                            WriteMetadata
                                (\metadata ->
                                    { metadata
                                        | description =
                                            if text == "" then
                                                Nothing

                                            else
                                                Just text
                                    }
                                )
                        )
                    ]
                    []
                ]
            , Html.div [ class "builder--field" ]
                [ Html.label [ Html.Attributes.for "metadata_lang" ] [ Html.text "Language Code" ]
                , Html.input
                    [ Html.Attributes.value model.file.metadata.lang
                    , Html.Attributes.id "metadata_lang"
                    , Html.Attributes.required True
                    , Html.Events.onInput
                        (\text ->
                            WriteMetadata
                                (\metadata ->
                                    { metadata | lang = text }
                                )
                        )
                    ]
                    []
                ]
            ]
        , Html.div [ class "builder--section" ]
            [ Html.span [ class "builder--section--title" ]
                [ Html.text "Steps"
                ]
            , Html.ul
                [ class "builder--grid" ]
                ((model.file.steps
                    |> List.indexedMap
                        (\i ->
                            \step ->
                                let
                                    idPrefix =
                                        "steps_" ++ String.fromInt i ++ "__"

                                    write : (Ptimer.Step -> Ptimer.Step) -> Msg
                                    write f =
                                        WriteSteps
                                            (\steps ->
                                                steps
                                                    |> List.map
                                                        (\s ->
                                                            if s.id == step.id then
                                                                f s

                                                            else
                                                                s
                                                        )
                                            )
                                in
                                Html.li
                                    [ class "builder--grid--cell"
                                    , case model.dragging of
                                        Dragging src dragover ->
                                            if src == step then
                                                class "builder--grid--cell--dragging"

                                            else if dragover == Just step then
                                                class "builder--grid--cell--dragover"

                                            else
                                                class ""

                                        _ ->
                                            class ""
                                    , Html.Attributes.draggable "true"
                                    , Html.Events.preventDefaultOn "dragenter" (Json.Decode.succeed ( DragEnter step, True ))
                                    , Html.Events.preventDefaultOn "dragleave" (Json.Decode.succeed ( DragLeave step, True ))
                                    , Html.Events.preventDefaultOn "dragover" (Json.Decode.succeed ( NoOp, True ))
                                    , Html.Events.preventDefaultOn "drop" (Json.Decode.succeed ( Drop step, True ))
                                    , Html.Events.on "dragend" (Json.Decode.succeed DragEnd)
                                    , Html.Events.custom "dragstart"
                                        (Json.Decode.succeed
                                            { message = DragStart step
                                            , preventDefault = False
                                            , stopPropagation = True
                                            }
                                        )
                                    ]
                                    [ Html.span
                                        [ class "builder--step--header" ]
                                        [ Html.span [] [ Html.text ("#" ++ String.fromInt (i + 1)) ]
                                        , Html.span [ class "builder--step--header--draggable" ] [ Html.text "::" ]
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "title") ]
                                            [ Html.text "Title" ]
                                        , Html.input
                                            [ Html.Attributes.value step.title
                                            , Html.Attributes.id (idPrefix ++ "title")
                                            , Html.Attributes.required True
                                            , Html.Events.onInput
                                                (\text ->
                                                    write (\s -> { s | title = text })
                                                )
                                            ]
                                            []
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "desc") ]
                                            [ Html.text "Description" ]
                                        , Html.input
                                            [ Html.Attributes.value (step.description |> Maybe.withDefault "")
                                            , Html.Attributes.id (idPrefix ++ "desc")
                                            , Html.Events.onInput
                                                (\text ->
                                                    write
                                                        (\s ->
                                                            { s
                                                                | description =
                                                                    if text == "" then
                                                                        Nothing

                                                                    else
                                                                        Just text
                                                            }
                                                        )
                                                )
                                            ]
                                            []
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "sound") ]
                                            [ Html.text "Sound" ]
                                        , Html.select
                                            [ Html.Attributes.id (idPrefix ++ "sound")
                                            , Html.Events.onInput
                                                (\value ->
                                                    write (\s -> { s | sound = findAsset value model.file.assets |> Maybe.map .id })
                                                )
                                            ]
                                            (Html.option [ Html.Attributes.value "" ] [ Html.text "None" ]
                                                :: List.map
                                                    (\asset ->
                                                        Html.option
                                                            [ Html.Attributes.value (Ptimer.assetIdToString asset.id)
                                                            , Html.Attributes.selected (step.sound == Just asset.id)
                                                            ]
                                                            [ Html.text ("#" ++ Ptimer.assetIdToString asset.id ++ " ")
                                                            , Html.text asset.name
                                                            ]
                                                    )
                                                    model.file.assets
                                            )
                                        , Html.span
                                            [ class "builder--field--caret"
                                            , Html.Attributes.attribute "aria-hidden" "true"
                                            ]
                                            []
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "mode") ]
                                            [ Html.text "Type" ]
                                        , Html.select
                                            [ Html.Attributes.for (idPrefix ++ "mode")
                                            , Html.Events.onInput
                                                (\value ->
                                                    case value of
                                                        "manual" ->
                                                            write (\s -> { s | action = Ptimer.UserInteraction })

                                                        "timer" ->
                                                            write
                                                                (\s ->
                                                                    { s | action = Ptimer.Timer 5 }
                                                                )

                                                        _ ->
                                                            NoOp
                                                )
                                            ]
                                            [ Html.option
                                                [ Html.Attributes.value "manual"
                                                , Html.Attributes.selected (step.action == Ptimer.UserInteraction)
                                                ]
                                                [ Html.text "User Interaction" ]
                                            , Html.option
                                                [ Html.Attributes.value "timer"
                                                , Html.Attributes.selected
                                                    (case step.action of
                                                        Ptimer.Timer _ ->
                                                            True

                                                        _ ->
                                                            False
                                                    )
                                                ]
                                                [ Html.text "Timer" ]
                                            ]
                                        , Html.span
                                            [ class "builder--field--caret"
                                            , Html.Attributes.attribute "aria-hidden" "true"
                                            ]
                                            []
                                        ]
                                    , case step.action of
                                        Ptimer.UserInteraction ->
                                            Html.text ""

                                        Ptimer.Timer seconds ->
                                            Html.div
                                                [ class "builder--field" ]
                                                [ Html.label [ Html.Attributes.for (idPrefix ++ "duration") ] [ Html.text "Duration (seconds)" ]
                                                , Html.input
                                                    [ Html.Attributes.value (String.fromInt seconds)
                                                    , id (idPrefix ++ "duration")
                                                    , Html.Attributes.type_ "number"
                                                    , Html.Attributes.min "0"
                                                    , Html.Attributes.step "1"
                                                    , Html.Attributes.required True
                                                    , Html.Events.onInput
                                                        (\text ->
                                                            case String.toInt text of
                                                                Just n ->
                                                                    write (\s -> { s | action = Ptimer.Timer n })

                                                                Nothing ->
                                                                    NoOp
                                                        )
                                                    ]
                                                    []
                                                ]
                                    , Html.button
                                        [ class "builder--delete"
                                        , Html.Attributes.type_ "button"
                                        , Html.Events.onClick (WriteSteps (List.filter (\s -> not (s == step))))
                                        ]
                                        [ Html.text "Delete" ]
                                    ]
                        )
                 )
                    ++ [ Html.li
                            [ class "builder--grid--cell builder--grid--cell--append" ]
                            [ Html.button
                                [ class "shared--button"
                                , Html.Attributes.type_ "button"
                                , Html.Events.onClick AppendStep
                                ]
                                [ Html.text "Add" ]
                            ]
                       ]
                )
            ]
        , Html.div [ class "builder--section" ]
            [ Html.span [ class "builder--section--title" ]
                [ Html.text "Assets"
                ]
            , Html.ul
                [ class "builder--grid" ]
                ((model.file.assets
                    |> List.indexedMap
                        (\i ->
                            \asset ->
                                let
                                    idPrefix =
                                        "assets_" ++ String.fromInt i ++ "__"
                                in
                                Html.li
                                    [ class "builder--grid--cell" ]
                                    [ Html.span [] [ Html.text ("#" ++ String.fromInt (i + 1)) ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "name") ]
                                            [ Html.text "Name" ]
                                        , Html.input
                                            [ Html.Attributes.value asset.name
                                            , Html.Attributes.id (idPrefix ++ "name")
                                            , Html.Attributes.required True
                                            , Html.Events.onInput
                                                (\text ->
                                                    WriteAssets
                                                        (List.map
                                                            (\a ->
                                                                if a.id == asset.id then
                                                                    { a | name = text }

                                                                else
                                                                    a
                                                            )
                                                        )
                                                )
                                            ]
                                            []
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "mime") ]
                                            [ Html.text "MIME" ]
                                        , Html.input
                                            [ Html.Attributes.value asset.mime
                                            , Html.Attributes.id (idPrefix ++ "mime")
                                            , Html.Attributes.required True
                                            , Html.Events.onInput
                                                (\text ->
                                                    WriteAssets
                                                        (List.map
                                                            (\a ->
                                                                if a.id == asset.id then
                                                                    { a | mime = text }

                                                                else
                                                                    a
                                                            )
                                                        )
                                                )
                                            ]
                                            []
                                        ]
                                    , Html.div
                                        [ class "builder--field" ]
                                        [ Html.label
                                            [ Html.Attributes.for (idPrefix ++ "notice") ]
                                            [ Html.text "Notice" ]
                                        , Html.input
                                            [ Html.Attributes.value (asset.notice |> Maybe.withDefault "")
                                            , Html.Attributes.id (idPrefix ++ "notice")
                                            , Html.Events.onInput
                                                (\text ->
                                                    WriteAssets
                                                        (List.map
                                                            (\a ->
                                                                if a.id == asset.id then
                                                                    { a
                                                                        | notice =
                                                                            if text == "" then
                                                                                Nothing

                                                                            else
                                                                                Just text
                                                                    }

                                                                else
                                                                    a
                                                            )
                                                        )
                                                )
                                            ]
                                            []
                                        ]
                                    , Html.button
                                        [ class "builder--delete"
                                        , Html.Attributes.type_ "button"
                                        , Html.Events.onClick (DeleteAsset asset)
                                        ]
                                        [ Html.text "Delete" ]
                                    ]
                        )
                 )
                    ++ [ Html.li
                            [ class "builder--grid--cell builder--grid--cell--append" ]
                            [ Html.label
                                [ class "shared--button"
                                ]
                                [ Html.input
                                    [ Html.Attributes.type_ "file"
                                    , Html.Attributes.accept "audio/wav,audio/flac,audio/mp3"
                                    , Html.Events.on
                                        "change"
                                        (Json.Decode.map RequestFileURL fileDecoder)
                                    ]
                                    []
                                , Html.text "Add"
                                ]
                            ]
                       ]
                )
            ]
        , Html.div [ class "builder--spacer" ] []
        , Html.div
            [ class "builder--actions" ]
            [ Html.button
                [ Html.Attributes.type_ "submit"
                , class "shared--button"
                , Html.Attributes.disabled
                    (case model.compilation of
                        Compiling _ ->
                            True

                        _ ->
                            False
                    )
                ]
                [ Html.text "Compile" ]
            , case model.compilation of
                Compiled file url ->
                    if file == model.file then
                        Html.a
                            [ class "shared--button"
                            , Html.Attributes.href url
                            , Html.Attributes.download (file.metadata.title ++ ".ptimer")
                            ]
                            [ Html.text "Download" ]

                    else
                        Html.button
                            [ Html.Attributes.type_ "button"
                            , Html.Attributes.disabled True
                            , class "shared--button"
                            ]
                            [ Html.text "Download" ]

                _ ->
                    Html.button
                        [ Html.Attributes.type_ "button"
                        , Html.Attributes.disabled True
                        , class "shared--button"
                        ]
                        [ Html.text "Download" ]
            ]
        , Html.ul
            [ class "builder--errors"
            , Html.Attributes.attribute "aria-live" "polite"
            , Html.Attributes.attribute "aria-relavant" "additions"
            ]
            (model.errors
                |> List.indexedMap
                    (\i ->
                        \error ->
                            case error of
                                Visible text ->
                                    Html.li [ class "builder--errors--item" ]
                                        [ Html.span [] [ Html.text text ]
                                        , Html.button
                                            [ Html.Attributes.type_ "button"
                                            , class "builder--errors--item--dismiss"
                                            , Html.Events.onClick (DismissError i)
                                            ]
                                            [ Html.text "Dismiss" ]
                                        ]

                                Dismissed _ ->
                                    Html.li [ Html.Attributes.style "display" "none" ] []
                    )
            )
        ]



-- SUBSCRIPTIONS


type alias FileUrlResult =
    { url : String
    , mime : String
    , name : String
    }


fileUrlDecoder : Json.Decode.Decoder FileUrlResult
fileUrlDecoder =
    Json.Decode.map3
        FileUrlResult
        (Json.Decode.field "url" Json.Decode.string)
        (Json.Decode.field "mime" Json.Decode.string)
        (Json.Decode.field "name" Json.Decode.string)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ builderBuilderReceiveFileUrl
            (\value ->
                case Json.Decode.decodeValue fileUrlDecoder value of
                    Ok result ->
                        AppendAsset
                            (\id ->
                                { id = id
                                , name = result.name
                                , mime = result.mime
                                , url = result.url
                                , notice = Nothing
                                }
                            )

                    Err _ ->
                        NoOp
            )
        , builderBuilderReceiveCompiledFile GotCompiledFile
        , builderBuilderReceiveCompileError GotCompileError
        ]
