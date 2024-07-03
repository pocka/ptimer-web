-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


port module WakeLock exposing
    ( WakeLock(..)
    , WakeLockSentinel
    , acquire
    , decoder
    , release
    , requestStatus
    , subscriptions
    )

import Json.Decode as JD



-- PORT


port sendWakeLockStatusRequest : () -> Cmd msg


port sendWakeLockAcquireRequest : () -> Cmd msg


port sendWakeLockReleaseRequest : JD.Value -> Cmd msg


port receiveWakeLockState : (JD.Value -> msg) -> Sub msg



-- UPDATE


requestStatus : Cmd msg
requestStatus =
    sendWakeLockStatusRequest ()


acquire : Cmd msg
acquire =
    sendWakeLockAcquireRequest ()


release : WakeLockSentinel -> Cmd msg
release sentinel =
    case sentinel of
        WakeLockSentinel value ->
            sendWakeLockReleaseRequest value



-- MODEL


type WakeLockSentinel
    = WakeLockSentinel JD.Value


type WakeLock
    = NotAvailable
    | RequestingStatus
    | Unlocked
    | AcquiringLock
    | Locked WakeLockSentinel
    | ReleasingLock


decoder : JD.Decoder WakeLock
decoder =
    JD.field "type" JD.string
        |> JD.andThen
            (\t ->
                case t of
                    "NotAvailable" ->
                        JD.succeed NotAvailable

                    "RequestingStatus" ->
                        JD.succeed RequestingStatus

                    "Unlocked" ->
                        JD.succeed Unlocked

                    "AcquiringLock" ->
                        JD.succeed AcquiringLock

                    "Locked" ->
                        JD.map Locked (JD.field "sentinel" JD.value |> JD.map WakeLockSentinel)

                    "ReleasingLock" ->
                        JD.succeed ReleasingLock

                    _ ->
                        JD.fail ("Unknown WakeLock status: " ++ t)
            )



-- SUBSCRIPTIONS


subscriptions : (Result JD.Error WakeLock -> msg) -> Sub msg
subscriptions f =
    receiveWakeLockState
        (\value ->
            value
                |> JD.decodeValue decoder
                |> f
        )
