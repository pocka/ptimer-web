-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module UI.DropZone exposing (onDragEnter, onDragLeave, onDrop, view)

import Html
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode



-- PORTS


port uiDropZoneReceiveDragEnter : (Json.Decode.Value -> msg) -> Sub msg



-- VIEW


onDragLeave : msg -> Html.Attribute msg
onDragLeave msg =
    Html.Events.preventDefaultOn "dragleave" (Json.Decode.succeed ( msg, True ))


dropDecoder : Json.Decode.Decoder Json.Decode.Value
dropDecoder =
    Json.Decode.at [ "dataTransfer", "files" ]
        (Json.Decode.index 0 Json.Decode.value)


onDrop : (Json.Decode.Value -> msg) -> Html.Attribute msg
onDrop msg =
    Html.Events.preventDefaultOn
        "drop"
        (Json.Decode.map (\value -> ( msg value, True )) dropDecoder)


view : List (Html.Attribute msg) -> List (Html.Html msg) -> Html.Html msg
view attrs children =
    Html.div
        (class "ui--dropzone" :: attrs)
        [ Html.node "lucide-upload" [ class "ui--dropzone--icon" ] []
        , Html.p [ class "ui--dropzone--desc" ] children
        ]



-- SUBSCRIPTIONS


onDragEnter : msg -> Sub msg
onDragEnter msg =
    uiDropZoneReceiveDragEnter (\_ -> msg)
