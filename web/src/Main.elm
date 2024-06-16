-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Main exposing (main)

import Browser
import Html exposing (p, text)



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


type alias Model =
    ()


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( (), Cmd.none )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Browser.Document Msg
view _ =
    { title = "Timer (web)"
    , body = [ p [] [ text "Hello, World!" ] ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
