-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module Ptimer.Parser exposing (ParseError(..), onReceiveParseResult, request)

import Json.Decode
import Ptimer.Ptimer as Ptimer



-- PORTS


port ptimerParserRequestParse : Json.Decode.Value -> Cmd msg


port ptimerParserReceiveParsedFile : (Json.Decode.Value -> msg) -> Sub msg


port ptimerParserReceiveParseError : (String -> msg) -> Sub msg



-- UPDATE


request : Json.Decode.Value -> Cmd msg
request file =
    ptimerParserRequestParse file



-- SUBSCRIPTIONS


type ParseError
    = DecodeError Json.Decode.Error
    | FormatError String


onReceiveParseResult : (Result ParseError Ptimer.PtimerFile -> msg) -> Sub msg
onReceiveParseResult msg =
    Sub.batch
        [ ptimerParserReceiveParsedFile
            (\value ->
                value
                    |> Json.Decode.decodeValue Ptimer.decoder
                    |> Result.mapError DecodeError
                    |> msg
            )
        , ptimerParserReceiveParseError (\error -> error |> FormatError |> Err |> msg)
        ]
