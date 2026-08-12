# frozen_string_literal: true

require "spec_helper"
require_relative "support/shadcn_source"

# Ties the port to upstream: for every ported component it reads the TSX in
# `vendor/shadcn/ui`, pulls out every Tailwind class React emits, and asserts
# each one is present somewhere in the family's Ruby.
#
# Be precise about what that does and does not prove. It compares *sets of
# tokens per family*, so it catches a class that was dropped, mistyped, or that
# upstream added. It does **not** know which part or which variant a class
# belongs to: swap two variants' bodies and this spec stays green.
# `snapshot_spec.rb` is what covers that, by diffing the rendered HTML.
#
# The two are complementary — this one watches upstream, that one watches the
# output — and neither alone is "1:1 verified".
RSpec.describe "shadcn/ui parity" do
  # TSX file => the component directory that ports it.
  ports = {
    "accordion" => "accordion",
    "alert" => "alert",
    "alert-dialog" => "alert_dialog",
    "aspect-ratio" => "aspect_ratio",
    "attachment" => "attachment",
    "avatar" => "avatar",
    "badge" => "badge",
    "breadcrumb" => "breadcrumb",
    "bubble" => "bubble",
    "button" => "button",
    "button-group" => "button_group",
    "card" => "card",
    "carousel" => "carousel",
    "checkbox" => "checkbox",
    "collapsible" => "collapsible",
    "context-menu" => "context_menu",
    "dialog" => "dialog",
    "dropdown-menu" => "dropdown_menu",
    "empty" => "empty",
    "field" => "field",
    "hover-card" => "hover_card",
    "input" => "input",
    "input-group" => "input_group",
    "input-otp" => "input_otp",
    "item" => "item",
    "kbd" => "kbd",
    "label" => "label",
    "marker" => "marker",
    "drawer" => "drawer",
    "message-scroller" => "message_scroller",
    "message" => "message",
    "menubar" => "menubar",
    "native-select" => "native_select",
    "navigation-menu" => "navigation_menu",
    "pagination" => "pagination",
    "popover" => "popover",
    "progress" => "progress",
    "radio-group" => "radio_group",
    "scroll-area" => "scroll_area",
    "select" => "select",
    "separator" => "separator",
    "sidebar" => "sidebar",
    "sheet" => "sheet",
    "skeleton" => "skeleton",
    "slider" => "slider",
    "spinner" => "spinner",
    "switch" => "switch",
    "table" => "table",
    "tabs" => "tabs",
    "textarea" => "textarea",
    "toggle" => "toggle",
    "toggle-group" => "toggle_group",
    "tooltip" => "tooltip"
  }.freeze

  # Vendored for reference but not ported yet. Kept here rather than in a
  # document so the two lists cannot drift: adding a TSX without deciding which
  # side it belongs on fails the example below, which is the whole point of it.
  # A category of one, and it needs its own list rather than a home in either of
  # the two below. `direction.tsx` wraps Radix's `DirectionProvider`, which is a
  # React context and renders no DOM: there are no classes to compare, so the
  # example that reads them would fail on an empty extraction. It is ported —
  # `app/javascript/shadcn/direction.js` and the three controllers that read it
  # — and it has no markup to be checked against.
  no_markup = %w[direction].freeze

  # Ported by something that is not a component. `form.tsx` is react-hook-form's
  # field state given five wrappers; the state has no counterpart on a server,
  # and the wrappers' job — id, name, `aria-describedby`, `aria-invalid`, the
  # error text — is Rails' FormBuilder's. So `ShadcnViewComponent::FormBuilder`
  # is where this family went, over the `Field` components upstream also builds
  # its own newer form examples on.
  #
  # It is a separate list from `not_yet_ported` because that one is a promise:
  # everything in it is meant to arrive one day, and `form` is not. The
  # divergences that follow from the decision are in features/form.md, and
  # nothing here checks them — this port emits `field-*` slots where upstream's
  # form emits `form-*`, so a class comparison would only restate that.
  ported_as_a_form_builder = %w[form].freeze

  not_yet_ported = %w[
    calendar chart combobox command
    resizable
    sonner
  ].freeze

  # Families that reuse parts of another rather than restating their classes.
  # Families layered on another's parts. The context menu is the largest case:
  # eleven of its fifteen slots are the dropdown's, restamped, which is why it
  # has no controller of its own either.
  inherits = {
    "sheet" => %w[dialog],
    "alert_dialog" => %w[dialog],
    "context_menu" => %w[dropdown_menu],
    "drawer" => %w[dialog],
    "menubar" => %w[dropdown_menu]
  }.freeze

  # Tokens the port legitimately does not carry. `--gap` is a bare CSS variable
  # the tokenizer picks out of an inline style, not a utility.
  allowed_missing = {
    "toggle-group" => %w[--gap],
    # The `data-slot` on `HoverCardPrimitive.Portal`. Nothing is portalled here
    # — the decision the whole JavaScript layer rests on, in
    # decisions/02-javascript.md — so there is no element to carry it. Every
    # other family with a Portal hits this too; this is the first one whose
    # portal is the only thing between the root and the content, so it is the
    # first where the slot name reaches the tokenizer at all.
    "hover-card" => %w[hover-card-portal],
    # The same, for the same reason: nothing is portalled here, so there is no
    # element to carry the Portal's slot.
    "context-menu" => %w[context-menu-portal],
    # The same again: nothing is portalled here.
    "menubar" => %w[menubar-portal],
    # The whole of `NavigationMenuViewport`. Upstream's default moves every
    # panel into one shared box that animates between their sizes — measured on
    # the live demo, the content's parent is `navigation-menu-viewport`, which
    # means React portalled it there. Nothing is portalled here, so this port
    # ships the `viewport={false}` configuration shadcn also supports, and the
    # box that would hold nothing is not rendered at all. Shipping it empty
    # would put an element in the page that looks like the component working.
    # `NavigationMenuIndicator` goes with it: the little arrow exists to point at
    # that shared box, and measured on the live demo **upstream's own examples
    # render none** — both are `viewport="true"` and neither uses one. In this
    # configuration each panel already carries its own border and shadow, so an
    # arrow lands on top of it pointing at nothing.
    # See features/navigation-menu.md.
    "navigation-menu" => %w[
      navigation-menu-indicator top-full z-[1] h-1.5 items-end overflow-hidden
      data-[state=hidden]:animate-out data-[state=hidden]:fade-out
      data-[state=visible]:animate-in data-[state=visible]:fade-in
      top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md
      navigation-menu-viewport origin-top-center mt-1.5 z-50 bg-popover
      text-popover-foreground h-[var(--radix-navigation-menu-viewport-height)]
      md:w-[var(--radix-navigation-menu-viewport-width)]
      data-[state=closed]:animate-out data-[state=closed]:zoom-out-95
      data-[state=open]:animate-in data-[state=open]:zoom-in-90
    ],
    # Three kinds, all deliberate.
    #
    # `--sidebar-width` and friends are bare CSS variables the tokenizer picks
    # out of an inline style, like `--gap` above. The port emits them, but
    # inside an interpolated Ruby string, so the literal it sees is
    # `--sidebar-width: ` rather than the bare name.
    #
    # The hyphenated `data-sidebar` values are *derived* rather than written:
    # `sidebar_part` builds them from the slot name, so they are in no string
    # literal here. Only the hyphenated ones show up as missing — the tokenizer
    # requires Tailwind punctuation, so `header` and `content` never counted as
    # classes in the first place.
    #
    # `[&>button]:hidden` belongs to the mobile Sheet branch, which this port
    # does not render at all: the controller gives the desktop tree a Sheet's
    # behaviour instead. See decisions/02-javascript.md.
    "sidebar" => %w[
      --sidebar-width --sidebar-width-icon --skeleton-width
      group-action group-content group-label
      menu-badge menu-item menu-sub menu-sub-item
      [&>button]:hidden
    ]
  }.freeze

  # `data-slot`s this port carries that no vendored TSX does. Parity is one-way —
  # it asserts upstream's classes are present, never that ours are upstream's —
  # so these are invisible to it. They are declared anyway: `todo.md` still wants
  # a reverse-parity check keyed on `data-slot`, and this list is what such a
  # check must not flag. The searchable select is deliberate divergence, not
  # drift; the reasoning is in `decisions/01-architecture.md`.
  # Not `select-input`, which upstream's aria variant stamps onto its
  # InputGroupInput. This port's input-group keys its focus ring on
  # `has-[[data-slot=input-group-control]:focus-visible]`, where the aria one
  # styles focus through `cn-*` and has no such selector — so restamping the
  # control here would silently switch the ring off.
  ours_alone = {
    "select" => %w[select-input-wrapper select-list select-empty]
  }.freeze

  it "declares the slots this port adds beyond upstream" do
    ours_alone.each do |family, slots|
      source = Dir[Pathname(__dir__).join("../app/components/shadcn", family, "**/*.rb")]
               .map { |path| File.read(path) }.join

      slots.each do |slot|
        expect(source).to include(slot),
                          "#{family} declares #{slot} in parity_spec but no component emits it"
      end
    end
  end

  it "accounts for every component vendored for comparison" do
    accounted = ports.keys + not_yet_ported + no_markup + ported_as_a_form_builder

    expect(accounted.sort).to eq(ShadcnSource.vendored_components)
  end

  ports.each do |tsx, directory|
    it "carries every Tailwind class #{tsx}.tsx emits", :aggregate_failures do
      allowed = allowed_missing.fetch(tsx, [])
      ported = ShadcnSource.ruby_classes(directory, also: inherits.fetch(directory, []))
      expected = ShadcnSource.tsx_classes(tsx)

      # Without this the comparison is vacuous when the tokenizer stops
      # matching: nothing extracted means nothing missing means green.
      expect(expected).not_to be_empty, "no classes were extracted from #{tsx}.tsx"

      missing = expected.reject do |klass|
        ported.include?(klass) || allowed.include?(klass)
      end

      expect(missing).to be_empty,
                         "#{tsx}.tsx uses classes the Ruby port does not: #{missing.sort.join(' ')}"
    end
  end
end
