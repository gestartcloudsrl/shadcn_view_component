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
  PORTS = {
    "accordion" => "accordion",
    "alert" => "alert",
    "alert-dialog" => "alert_dialog",
    "aspect-ratio" => "aspect_ratio",
    "avatar" => "avatar",
    "badge" => "badge",
    "breadcrumb" => "breadcrumb",
    "button" => "button",
    "card" => "card",
    "checkbox" => "checkbox",
    "collapsible" => "collapsible",
    "dialog" => "dialog",
    "dropdown-menu" => "dropdown_menu",
    "field" => "field",
    "input" => "input",
    "kbd" => "kbd",
    "label" => "label",
    "native-select" => "native_select",
    "pagination" => "pagination",
    "popover" => "popover",
    "progress" => "progress",
    "radio-group" => "radio_group",
    "select" => "select",
    "separator" => "separator",
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

  # Families that reuse parts of another rather than restating their classes.
  INHERITS = { "sheet" => %w[dialog], "alert_dialog" => %w[dialog] }.freeze

  # Tokens the port legitimately does not carry. `--gap` is a bare CSS variable
  # the tokenizer picks out of an inline style, not a utility.
  ALLOWED_MISSING = { "toggle-group" => %w[--gap] }.freeze

  it "ports every component vendored for comparison" do
    expect(PORTS.keys.sort).to eq(ShadcnSource.vendored_components)
  end

  PORTS.each do |tsx, directory|
    it "carries every Tailwind class #{tsx}.tsx emits" do
      allowed = ALLOWED_MISSING.fetch(tsx, [])
      ported = ShadcnSource.ruby_classes(directory, also: INHERITS.fetch(directory, []))

      missing = ShadcnSource.tsx_classes(tsx).reject do |klass|
        ported.include?(klass) || allowed.include?(klass)
      end

      expect(missing).to be_empty,
                         "#{tsx}.tsx uses classes the Ruby port does not: #{missing.sort.join(' ')}"
    end
  end
end
