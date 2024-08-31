-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Core.Session exposing (Msg(..), Session, init, subscriptions, update)

import WakeLock



-- MODEL


type alias Session =
    { wakeLock : WakeLock.WakeLock
    }


init : ( Session, Cmd Msg )
init =
    ( { wakeLock = WakeLock.RequestingStatus }, WakeLock.requestStatus )



-- UPDATE


type Msg
    = UpdateWakeLock WakeLock.WakeLock
    | AcquireWakeLock
    | ReleaseWakeLock WakeLock.WakeLockSentinel
    | NoOp


update : Msg -> Session -> ( Session, Cmd Msg )
update msg session =
    case msg of
        UpdateWakeLock wakeLock ->
            ( { session | wakeLock = wakeLock }, Cmd.none )

        AcquireWakeLock ->
            ( { session | wakeLock = WakeLock.AcquiringLock }, WakeLock.acquire )

        ReleaseWakeLock sentinel ->
            ( { session | wakeLock = WakeLock.ReleasingLock }, WakeLock.release sentinel )

        NoOp ->
            ( session, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Session -> Sub Msg
subscriptions _ =
    WakeLock.subscriptions
        (\payload ->
            case payload of
                Ok wakeLock ->
                    UpdateWakeLock wakeLock

                _ ->
                    NoOp
        )
