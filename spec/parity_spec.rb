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
    "avatar" => "avatar",
    "badge" => "badge",
    "breadcrumb" => "breadcrumb",
    "button" => "button",
    "button-group" => "button_group",
    "card" => "card",
    "checkbox" => "checkbox",
    "collapsible" => "collapsible",
    "dialog" => "dialog",
    "dropdown-menu" => "dropdown_menu",
    "empty" => "empty",
    "field" => "field",
    "input" => "input",
    "input-group" => "input_group",
    "item" => "item",
    "kbd" => "kbd",
    "label" => "label",
    "native-select" => "native_select",
    "pagination" => "pagination",
    "popover" => "popover",
    "progress" => "progress",
    "radio-group" => "radio_group",
    "select" => "select",
    "separator" => "separator",
    "sidebar" => "sidebar",
    "sheet" => "sheet",
    "skeleton" => "skeleton",
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
  not_yet_ported = %w[
    attachment bubble calendar carousel chart combobox command
    context-menu direction drawer form hover-card input-otp
    marker menubar message message-scroller navigation-menu resizable
    scroll-area slider sonner
  ].freeze

  # Families that reuse parts of another rather than restating their classes.
  inherits = { "sheet" => %w[dialog], "alert_dialog" => %w[dialog] }.freeze

  # Tokens the port legitimately does not carry. `--gap` is a bare CSS variable
  # the tokenizer picks out of an inline style, not a utility.
  allowed_missing = {
    "toggle-group" => %w[--gap],
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
    expect((ports.keys + not_yet_ported).sort).to eq(ShadcnSource.vendored_components)
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
