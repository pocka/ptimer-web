-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Player.Menu exposing (view)

import Html
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Player.Session as Session
import WakeLock



-- VIEW


wakeLockButton : Session.Session -> Html.Html Session.Msg
wakeLockButton session =
    Html.button
        [ class "player-menu--button"
        , Html.Attributes.disabled
            (case session.wakeLock of
                WakeLock.RequestingStatus ->
                    True

                WakeLock.NotAvailable ->
                    True

                WakeLock.AcquiringLock ->
                    True

                WakeLock.ReleasingLock ->
                    True

                _ ->
                    False
            )
        , Html.Attributes.title
            (case session.wakeLock of
                WakeLock.RequestingStatus ->
                    "Checking Screen WakeLock status"

                WakeLock.NotAvailable ->
                    "Screen WakeLock is not available on this platform"

                WakeLock.Unlocked ->
                    "Screen WakeLock is off"

                WakeLock.AcquiringLock ->
                    "Acquiring Screen WakeLock"

                WakeLock.Locked _ ->
                    "Screen WakeLock is on"

                WakeLock.ReleasingLock ->
                    "Releasing Screen WakeLock"
            )
        , onClick
            (case session.wakeLock of
                WakeLock.Unlocked ->
                    Session.AcquireWakeLock

                WakeLock.Locked sentinel ->
                    Session.ReleaseWakeLock sentinel

                _ ->
                    Session.NoOp
            )
        ]
        [ Html.node
            (case session.wakeLock of
                WakeLock.AcquiringLock ->
                    "lucide-lock"

                WakeLock.Locked _ ->
                    "lucide-lock"

                _ ->
                    "lucide-lock-open"
            )
            []
            []
        ]


view : Session.Session -> Html.Html Session.Msg
view session =
    Html.div
        [ class "player-menu--root" ]
        [ wakeLockButton session ]
