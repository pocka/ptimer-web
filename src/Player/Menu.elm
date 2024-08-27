-- SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
--
-- SPDX-License-Identifier: Apache-2.0


module Player.Menu exposing (Msg(..), view)

import Html
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Player.Preferences as Preferences
import Player.Session as Session
import WakeLock



-- UPDATE


type Msg
    = SessionMsg Session.Msg
    | PreferencesMsg Preferences.Msg



-- VIEW


wakeLockButton : Session.Session -> Html.Html Msg
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
            ((case session.wakeLock of
                WakeLock.Unlocked ->
                    Session.AcquireWakeLock

                WakeLock.Locked sentinel ->
                    Session.ReleaseWakeLock sentinel

                _ ->
                    Session.NoOp
             )
                |> SessionMsg
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


muteButton : Preferences.Model -> Html.Html Msg
muteButton preferences =
    Html.button
        [ class "player-menu--button"
        , Html.Attributes.title
            (case preferences.value.audio of
                Preferences.Muted ->
                    "Click to unmute"

                Preferences.Unmuted ->
                    "Click to mute"
            )
        , onClick
            ((case preferences.value.audio of
                Preferences.Muted ->
                    Preferences.Unmute

                Preferences.Unmuted ->
                    Preferences.Mute
             )
                |> PreferencesMsg
            )
        ]
        [ Html.node
            (case preferences.value.audio of
                Preferences.Muted ->
                    "lucide-volume-x"

                Preferences.Unmuted ->
                    "lucide-volume-2"
            )
            []
            []
        ]


view : Session.Session -> Preferences.Model -> Html.Html Msg
view session preferences =
    Html.div
        [ class "player-menu--root" ]
        [ wakeLockButton session
        , muteButton preferences
        ]
