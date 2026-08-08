# frozen_string_literal: true

require "spec_helper"
require "cgi"
require "set"

# The other direction from `parity_spec.rb`. That one asks whether every class
# upstream emits is present here; this one asks whether every class *we render*
# still exists upstream at all. Without it, a class shadcn deletes stays in the
# port forever and nothing complains.
#
# Two earlier designs were measured and rejected, and the reasons matter because
# they shaped this one:
#
# 1. **Per-family token sets from Ruby string literals.** 12 of 13 families came
#    back dirty: `select-item`, `chevron-down` and `more-horizontal` are all
#    shaped like Tailwind utilities, so slot names, icon names and constants
#    counted as classes.
# 2. **Per-slot, against the slot's own TSX file.** 56 of 145 slots dirty, all
#    of one shape: upstream writes `<DialogTrigger asChild><Button …>`, so
#    Button's classes land on `dialog-trigger` while living in `button.tsx`.
#    Fixing that needs a composition table per slot — the exception table whose
#    absence was the point.
#
# What is left compares the classes we *render* on each `data-slot` against the
# whole vendored corpus. Composition stops being a false positive, because
# Button's classes are in the corpus wherever they land. The trade is that it
# catches a class only when it survives nowhere upstream — a narrower net than
# per-slot, but one that needs no table of which component wraps which.
#
# It is not a substitute for `snapshot_spec.rb`, which is what notices a class
# moving between parts.
RSpec.describe "reverse parity" do
  # Rendered classes, per `data-slot`, from the snapshots — which are real
  # output, so a class attribute cannot contain a constant or an icon name the
  # way a Ruby string literal can.
  def rendered_by_slot
    Dir[Pathname(__dir__).join("fixtures/snapshots/*.html")].each_with_object(
      Hash.new { |hash, key| hash[key] = Set.new }
    ) do |path, slots|
      File.read(path).scan(/data-slot="([^"]+)"([^>]*)/) do |slot, attributes|
        classes = attributes[/\sclass="([^"]*)"/, 1]
        slots[slot].merge(CGI.unescapeHTML(classes).split(/\s+/)) if classes
      end
    end
  end

  # Every token in every vendored TSX, `examples/` included — the theming
  # components are ported from there, and leaving them out made ModeSwitcher's
  # classes look invented.
  def upstream_corpus
    Dir[Pathname(__dir__).join("../vendor/shadcn/**/*.tsx")].each_with_object(Set.new) do |path, corpus|
      File.read(path).scan(/"([^"\n]*)"/) { |(literal)| corpus.merge(literal.split(/\s+/)) }
    end
  end

  # Classes this port renders that no vendored source contains. Every one is
  # here on purpose, and the spec fails if that stops being true in either
  # direction — a new one appears, or a listed one goes away.
  #
  # Three kinds, and the first is the price of reading snapshots: a preview is a
  # caller, and callers may add classes.
  # A local, not a constant: a constant declared in a describe block lands on
  # Object. `LeakyLocalVariable` is off here for exactly this.
  ours = {
    # Sizing a preview passes in to demonstrate the component at a sensible
    # width. Nothing to do with the port.
    "accordion" => %w[w-[420px]],
    "collapsible" => %w[w-[420px]],
    "field-group" => %w[w-[420px]],
    "tabs" => %w[w-[420px]],
    "dropdown-menu-content" => %w[w-56],
    "select-trigger" => %w[w-[200px] w-[220px] w-[240px]],
    "skeleton" => %w[size-12 w-[200px] w-[250px]],
    "empty" => %w[max-w-md],
    "item" => %w[max-w-md],
    "item-group" => %w[max-w-md],
    "separator" => %w[my-4],

    # The searchable select, which is this gem's own component rather than a
    # port — no Radix base has one. Its classes come from shadcn's React Aria
    # variant, which is not vendored here, or from this port outright.
    # See decisions/01-architecture.md.
    "select-item" => %w[data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground],
    "select-list" => %w[group/select-list max-h-[inherit]],
    "select-input-wrapper" => %w[pb-0],

    # `Icon::Component` stamps `lucide lucide-<name>` itself, where upstream
    # mounts a React component whose classes never appear in the TSX text.
    "native-select-icon" => %w[lucide lucide-chevron-down]
  }.freeze

  it "renders no class that has disappeared from every vendored source", :aggregate_failures do
    corpus = upstream_corpus

    # Guards the comparison rather than the port: an extraction that silently
    # stopped matching would make every slot pass.
    expect(corpus.size).to be > 500

    rendered_by_slot.each do |slot, classes|
      unknown = classes - corpus - ours.fetch(slot, [])

      expect(unknown).to be_empty,
                         "#{slot} renders #{unknown.sort.join(' ')}, which no vendored TSX contains. " \
                         "If that is deliberate, add it to `ours` with the reason."
    end
  end

  it "lists nothing as ours that upstream has since adopted" do
    corpus = upstream_corpus
    adopted = ours.transform_values { |classes| classes & corpus.to_a }.reject { |_, v| v.empty? }

    expect(adopted).to be_empty,
                       "these are listed as ours but now appear upstream: #{adopted.inspect}"
  end
end
