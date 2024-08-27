// SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import builder/lucide
import builder/storybook
import gleam/dynamic
import gleam/function
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import lustre/event

// VIEW

@external(javascript, "@/builder/ui/button.ffi.ts", "className")
fn scoped(x: String) -> String

pub type VariantNotSet

pub type StateNotSet

pub type IconNotSet

pub type SizeNotSet

pub type Button(msg) {
  Button(on_click: msg)
  Link(href: String, target: Option(String))
  FilePicker(on_pick: fn(dynamic.Dynamic) -> msg, accepts: List(String))

  /// Renders a button but pressing it does nothing.
  /// Useful for disabled/loading buttons.
  NoOp
}

pub opaque type Config(msg, state, variant, size, icon) {
  Config(
    state: State,
    size: Size,
    button: Button(msg),
    variant: Variant,
    icon: Option(lucide.IconType),
  )
}

pub fn new(
  button: Button(msg),
) -> Config(msg, StateNotSet, VariantNotSet, SizeNotSet, IconNotSet) {
  Config(
    state: Enabled,
    size: Medium,
    button: button,
    variant: Normal,
    icon: None,
  )
}

pub fn state(
  config: Config(msg, StateNotSet, variant, size, icon),
  state: State,
) -> Config(msg, State, variant, size, icon) {
  Config(
    size: config.size,
    variant: config.variant,
    button: config.button,
    icon: config.icon,
    state: state,
  )
}

pub fn variant(
  config: Config(msg, state, VariantNotSet, size, icon),
  variant: Variant,
) -> Config(msg, state, Variant, size, icon) {
  Config(
    size: config.size,
    variant: variant,
    button: config.button,
    icon: config.icon,
    state: config.state,
  )
}

pub fn icon(
  config: Config(msg, state, variant, size, IconNotSet),
  icon: lucide.IconType,
) -> Config(msg, state, vartiant, size, lucide.IconType) {
  Config(
    size: config.size,
    variant: config.variant,
    button: config.button,
    icon: Some(icon),
    state: config.state,
  )
}

pub fn size(
  config: Config(msg, state, variant, SizeNotSet, icon),
  size: Size,
) -> Config(msg, state, variant, Size, icon) {
  Config(
    size: size,
    variant: config.variant,
    button: config.button,
    icon: config.icon,
    state: config.state,
  )
}

pub type State {
  /// User can press the button.
  Enabled

  /// User can't press the button.
  Disabled(reason: Option(String))

  /// An action the button triggers is running. User can't press the button.
  Loading(description: Option(String))
}

fn set_state_attrs(
  attrs: List(attribute.Attribute(msg)),
  state: State,
) -> List(attribute.Attribute(msg)) {
  case state {
    Enabled -> attrs

    Disabled(Some(details)) -> [
      attribute.attribute("aria-disabled", "true"),
      attribute.attribute("aria-details", details),
      class(scoped("disabled")),
      ..attrs
    ]

    Disabled(None) -> [
      attribute.disabled(True),
      class(scoped("disabled")),
      ..attrs
    ]

    Loading(Some(details)) -> [
      attribute.attribute("aria-disabled", "true"),
      attribute.attribute("aria-details", details),
      class(scoped("loading")),
      ..attrs
    ]

    Loading(None) -> [
      attribute.disabled(True),
      class(scoped("loading")),
      ..attrs
    ]
  }
}

pub type Variant {
  /// Prioritized button, the screen's primary action.
  Primary

  /// The button is not prioritized.
  Normal
}

fn variant_attr(variant: Variant) -> attribute.Attribute(msg) {
  case variant {
    Primary -> class(scoped("primary"))
    Normal -> class(scoped("normal"))
  }
}

pub type Size {
  Small
  Medium
}

fn size_attr(size: Size) -> attribute.Attribute(msg) {
  case size {
    Small -> class(scoped("small"))
    Medium -> class(scoped("medium"))
  }
}

@external(javascript, "@/builder/ui/button.ffi.ts", "getFirstFile")
fn get_first_file(ev: dynamic.Dynamic) -> dynamic.Dynamic

pub fn view(
  config: Config(msg, state, variant, size, icon),
  attrs: List(attribute.Attribute(msg)),
  children: List(element.Element(msg)),
) -> element.Element(msg) {
  let common_attrs =
    [
      size_attr(config.size),
      variant_attr(config.variant),
      class(scoped("button")),
      ..attrs
    ]
    |> set_state_attrs(config.state)

  let common_children = [
    case config.icon {
      Some(icon_type) -> lucide.icon(icon_type, [class(scoped("icon"))])

      None -> element.none()
    },
    html.span([], children),
  ]

  case config.button {
    Link(href, target) -> {
      let attrs = case config.state {
        Enabled -> common_attrs

        Disabled(details) -> [
          attribute.attribute("aria-disabled", "true"),
          details
            |> option.map(attribute.attribute("aria-details", _))
            |> option.unwrap(attribute.none()),
          event.on("click", fn(ev) {
            event.prevent_default(ev)
            Error([])
          }),
          ..common_attrs
        ]

        Loading(details) -> [
          attribute.attribute("aria-disabled", "true"),
          details
            |> option.map(attribute.attribute("aria-details", _))
            |> option.unwrap(attribute.none()),
          class(scoped("loading")),
          event.on("click", fn(ev) {
            event.prevent_default(ev)
            Error([])
          }),
          ..common_attrs
        ]
      }

      html.a(
        [
          attribute.href(href),
          target
            |> option.map(attribute.target)
            |> option.unwrap(attribute.none()),
          ..attrs
        ],
        common_children,
      )
    }
    FilePicker(on_pick, accepts) -> {
      let wrapper_attrs = case config.state {
        Loading(_) -> [class(scoped("loading")), ..common_attrs]
        _ -> common_attrs
      }

      let attrs = case config.state {
        Enabled -> [
          event.on("input", fn(ev) {
            get_first_file(ev)
            |> dynamic.optional(dynamic.dynamic)
            |> result.map(fn(file) {
              case file {
                Some(file) -> Ok(on_pick(file))
                _ -> Error([])
              }
            })
            |> result.flatten()
          }),
        ]

        _ -> [
          attribute.disabled(True),
          attribute.attribute("aria-disabled", "true"),
          case config.state {
            Disabled(Some(details)) ->
              attribute.attribute("aria-details", details)
            Loading(Some(details)) ->
              attribute.attribute("aria-details", details)
            _ -> attribute.none()
          },
        ]
      }

      html.label(wrapper_attrs, [
        html.input([
          class(scoped("visually-hidden")),
          attribute.type_("file"),
          case accepts {
            [] -> attribute.none()
            _ -> attribute.accept(accepts)
          },
          ..attrs
        ]),
        ..common_children
      ])
    }
    _ -> {
      let attrs = case config.state {
        Enabled -> [
          case config.button {
            Button(on_click) -> event.on_click(on_click)
            _ -> attribute.none()
          },
          ..common_attrs
        ]

        Disabled(Some(details)) -> [
          attribute.attribute("aria-disabled", "true"),
          attribute.attribute("aria-details", details),
          ..common_attrs
        ]

        Disabled(None) -> [attribute.disabled(True), ..common_attrs]

        Loading(Some(details)) -> [
          attribute.attribute("aria-disabled", "true"),
          attribute.attribute("aria-details", details),
          class(scoped("loading")),
          ..common_attrs
        ]

        Loading(None) -> [
          attribute.disabled(True),
          class(scoped("loading")),
          ..common_attrs
        ]
      }

      html.button([attribute.type_("button"), ..attrs], common_children)
    }
  }
}

pub fn story(args: storybook.Args, ctx: storybook.Context) -> storybook.Story {
  use selector, flags, action <- storybook.story(args, ctx)

  let button_type = case flags |> dynamic.field("type", dynamic.string) {
    Ok("link") -> Link("https://example.com", Some("_blank"))
    Ok("file_picker") -> FilePicker(fn(file) { #("on_pick", file) }, [])
    _ -> Button(#("on_click", dynamic.from(Nil)))
  }

  let variant_flag = case flags |> dynamic.field("variant", dynamic.string) {
    Ok("primary") -> Primary

    _ -> Normal
  }

  let state_flag = case flags |> dynamic.field("state", dynamic.string) {
    Ok("disabled") -> Disabled(None)

    Ok("loading") -> Loading(None)

    _ -> Enabled
  }

  let size_flag = case flags |> dynamic.field("size", dynamic.string) {
    Ok("small") -> Small
    Ok("medium") -> Medium
    _ -> Medium
  }

  let icon_f = case
    flags
    |> dynamic.field("icon", dynamic.bool)
  {
    Ok(True) -> fn(x) { icon(x, lucide.FileMusic) }

    _ -> fn(config: Config(a, b, c, d, IconNotSet)) -> Config(
      a,
      b,
      c,
      d,
      lucide.IconType,
    ) {
      Config(
        button: config.button,
        state: config.state,
        size: config.size,
        variant: config.variant,
        icon: None,
      )
    }
  }

  let _ =
    lustre.simple(
      function.identity,
      fn(a, b) {
        action("story_update", dynamic.from(b))
        a
      },
      fn(_) {
        new(button_type)
        |> variant(variant_flag)
        |> state(state_flag)
        |> size(size_flag)
        |> icon_f
        |> view([], [element.text("Hello, Storybook!")])
      },
    )
    |> lustre.start(selector, flags)

  Nil
}
