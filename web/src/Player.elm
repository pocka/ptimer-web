-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Player exposing (Model, Msg, init, subscriptions, update, view)

import Html
import Html.Attributes exposing (class, disabled)
import Html.Events exposing (onClick)
import Ptimer.Ptimer as Ptimer
import Task
import Time



-- MODEL


type alias Timer =
    { startAt : Time.Posix
    , duration : Int
    , remainings : Int
    }


type PlayState
    = NotStarted
    | Playing Ptimer.Step (List Ptimer.Step) (Maybe Timer)
    | Completed


type alias Model =
    { file : Ptimer.PtimerFile
    , state : PlayState
    }


init : Ptimer.PtimerFile -> ( Model, Cmd Msg )
init file =
    ( { file = file, state = NotStarted }, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | NextStep
    | Start
    | Reset
    | Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Start ->
            update NextStep model

        NextStep ->
            let
                steps =
                    case model.state of
                        Playing _ s _ ->
                            s

                        _ ->
                            model.file.steps
            in
            case steps of
                [] ->
                    ( { model | state = Completed }, Cmd.none )

                step :: rest ->
                    ( { model | state = Playing step rest Nothing }
                    , case step.action of
                        Ptimer.Timer _ ->
                            Task.perform Tick Time.now

                        _ ->
                            Cmd.none
                    )

        Tick now ->
            case model.state of
                Playing step rest (Just { startAt, duration }) ->
                    let
                        diff =
                            (Time.posixToMillis now - Time.posixToMillis startAt) // 1000
                    in
                    if diff >= duration then
                        update NextStep model

                    else
                        ( { model | state = Playing step rest (Just (Timer startAt duration (duration - diff))) }
                        , Cmd.none
                        )

                Playing step rest Nothing ->
                    case step.action of
                        Ptimer.Timer duration ->
                            ( { model | state = Playing step rest (Just (Timer now duration duration)) }
                            , Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Reset ->
            init model.file



-- VIEW


spacer : Html.Html msg
spacer =
    Html.div [ class "player--spacer" ] []


startScene : Model -> Html.Html Msg
startScene model =
    Html.div
        [ class "player--container"
        , case model.state of
            NotStarted ->
                class "active"

            _ ->
                class ""
        ]
        [ Html.p [ class "player--title" ] [ Html.text model.file.metadata.title ]
        , case model.file.metadata.description of
            Just description ->
                Html.p [] [ Html.text description ]

            Nothing ->
                Html.text ""
        , spacer
        , Html.button
            [ class "main--button"
            , case model.state of
                NotStarted ->
                    onClick Start

                _ ->
                    disabled True
            ]
            [ Html.text "Start" ]
        ]


stepScene : Model -> Ptimer.Step -> Html.Html Msg
stepScene model step =
    let
        isCurrent =
            case model.state of
                Playing current _ _ ->
                    current == step

                _ ->
                    False
    in
    Html.div
        [ class "player--container"
        , class
            (if isCurrent then
                "active"

             else
                ""
            )
        ]
        [ Html.p [ class "player--title" ] [ Html.text step.title ]
        , case step.description of
            Just description ->
                Html.p [] [ Html.text description ]

            Nothing ->
                Html.text ""
        , spacer
        , case step.action of
            Ptimer.Timer duration ->
                if isCurrent then
                    case model.state of
                        Playing _ _ (Just { remainings }) ->
                            Html.p [] [ Html.text ("wait " ++ String.fromInt remainings ++ " seconds") ]

                        _ ->
                            Html.p [] [ Html.text ("wait " ++ String.fromInt duration ++ " seconds") ]

                else
                    Html.p [] [ Html.text "wait 0 seconds" ]

            Ptimer.UserInteraction ->
                Html.button
                    [ class "main--button"
                    , if isCurrent then
                        onClick NextStep

                      else
                        disabled True
                    ]
                    [ Html.text "Next" ]
        ]


endScene : Model -> Html.Html Msg
endScene model =
    Html.div
        [ class "player--container"
        , case model.state of
            Completed ->
                class "active"

            _ ->
                class ""
        ]
        [ Html.p [ class "player--title" ] [ Html.text "Completed" ]
        , spacer
        , Html.button
            [ class "main--button"
            , case model.state of
                Completed ->
                    onClick Reset

                _ ->
                    disabled True
            ]
            [ Html.text "Back to start" ]
        ]


view : Model -> Html.Html Msg
view model =
    Html.div [ class "player--layout" ]
        [ Html.div
            [ class "player--grid" ]
            (startScene model :: (model.file.steps |> List.map (stepScene model)) ++ [ endScene model ])
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.state of
        Playing { action } _ _ ->
            case action of
                Ptimer.Timer _ ->
                    Time.every 500 Tick

                _ ->
                    Sub.none

        _ ->
            Sub.none
