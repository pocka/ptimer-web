-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Ptimer.Ptimer exposing
    ( Asset
    , AssetId
    , Metadata
    , PtimerFile
    , Step
    , StepAction(..)
    , StepId
    , appendAsset
    , appendStep
    , assetIdToString
    , decoder
    , new
    )

import Json.Decode as JD
import Json.Encode as JE


type AssetId
    = AssetId Int


assetIdDecoder : JD.Decoder AssetId
assetIdDecoder =
    JD.int |> JD.map AssetId


assetIdToString : AssetId -> String
assetIdToString id =
    case id of
        AssetId num ->
            String.fromInt num


type alias Asset =
    { id : AssetId
    , mime : String
    , name : String
    , notice : Maybe String
    , url : String
    }


assetDecoder : JD.Decoder Asset
assetDecoder =
    JD.map5
        Asset
        (JD.field "id" assetIdDecoder)
        (JD.field "mime" JD.string)
        (JD.field "name" JD.string)
        (JD.field "notice" (JD.nullable JD.string))
        (JD.field "url" JD.string)


getLargestAssetId : List Asset -> Maybe AssetId
getLargestAssetId assets =
    case assets of
        [] ->
            Nothing

        x :: xs ->
            case getLargestAssetId xs of
                Nothing ->
                    Just x.id

                Just (AssetId yi) ->
                    case x.id of
                        AssetId xi ->
                            Just (AssetId (max xi yi))


appendAsset : (AssetId -> Asset) -> List Asset -> List Asset
appendAsset f assets =
    assets
        ++ [ f
                (case getLargestAssetId assets of
                    Just (AssetId x) ->
                        AssetId (x + 1)

                    Nothing ->
                        AssetId 0
                )
           ]


type alias Metadata =
    { title : String
    , lang : String
    , description : Maybe String
    }


metadataDecoder : JD.Decoder Metadata
metadataDecoder =
    JD.map3
        Metadata
        (JD.field "title" JD.string)
        (JD.field "lang" JD.string)
        (JD.field "description" (JD.nullable JD.string))


type StepAction
    = Timer Int
    | UserInteraction


stepActionDecoder : JD.Decoder StepAction
stepActionDecoder =
    JD.field "duration_seconds" (JD.nullable JD.int)
        |> JD.map
            (\maybeDuration ->
                case maybeDuration of
                    Just duration ->
                        Timer duration

                    Nothing ->
                        UserInteraction
            )


type StepId
    = StepId Int


stepIdDecoder : JD.Decoder StepId
stepIdDecoder =
    JD.int |> JD.map StepId


type alias Step =
    { id : StepId
    , title : String
    , description : Maybe String
    , sound : Maybe AssetId
    , action : StepAction
    }


stepDecoder : JD.Decoder Step
stepDecoder =
    JD.map5
        Step
        (JD.field "id" stepIdDecoder)
        (JD.field "title" JD.string)
        (JD.field "description" (JD.nullable JD.string))
        (JD.field "sound" (JD.nullable assetIdDecoder))
        stepActionDecoder


getLargestStepId : List Step -> Maybe StepId
getLargestStepId steps =
    case steps of
        [] ->
            Nothing

        x :: xs ->
            case getLargestStepId xs of
                Nothing ->
                    Just x.id

                Just (StepId yi) ->
                    case x.id of
                        StepId xi ->
                            Just (StepId (max xi yi))


appendStep : List Step -> List Step
appendStep steps =
    let
        newStep : Step
        newStep =
            { id =
                case getLargestStepId steps of
                    Just (StepId x) ->
                        StepId (x + 1)

                    Nothing ->
                        StepId 0
            , title = ""
            , description = Nothing
            , sound = Nothing
            , action = UserInteraction
            }
    in
    steps ++ [ newStep ]


type alias PtimerFile =
    { metadata : Metadata
    , steps : List Step
    , assets : List Asset
    }


decoder : JD.Decoder PtimerFile
decoder =
    JD.map3
        PtimerFile
        (JD.field "metadata" metadataDecoder)
        (JD.field "steps" (JD.list stepDecoder))
        (JD.field "assets" (JD.list assetDecoder))


new : PtimerFile
new =
    { metadata =
        { title = ""
        , description = Nothing
        , lang = "en-US"
        }
    , steps = []
    , assets = []
    }
