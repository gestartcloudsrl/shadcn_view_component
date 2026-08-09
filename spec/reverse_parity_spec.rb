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

    "field-group" => %w[w-[420px]],
    "tabs" => %w[w-[420px]],
    "dropdown-menu-content" => %w[w-56],
    "select-trigger" => %w[w-[200px] w-[220px] w-[240px]],
    "skeleton" => %w[size-12 w-[200px] w-[250px]],
    "empty" => %w[max-w-md],
    "item" => %w[max-w-md],
    "item-group" => %w[max-w-md],
    "separator" => %w[my-4 my-2],
    # A hover card usually hangs off something already in a sentence, so the
    # preview's trigger is an underlined link. Caller styling, like the widths
    # above.
    "hover-card-trigger" => %w[underline],
    # The two boxes the scroll-area preview scrolls. A scroll area is `relative`
    # and nothing else — it is the caller who says how big the window is, which
    # is the whole point of the component.
    "scroll-area" => %w[h-64 w-48],
    # A named Tailwind group the sidebar preview passes to a Collapsible, so a
    # menu item's chevron can rotate when its own section opens. Upstream's
    # sidebar demo does the same, but demos are not vendored here — only
    # `ui/*.tsx` and `examples/` are — so the token exists in no source this
    # spec can see.
    "collapsible" => %w[w-[420px] group/collapsible],

    # The searchable select, which is this gem's own component rather than a
    # port — no Radix base has one. Its classes come from shadcn's React Aria
    # variant, which is not vendored here, or from this port outright.
    # See decisions/01-architecture.md.
    "select-item" => %w[data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground],
    "select-list" => %w[group/select-list max-h-[inherit]],
    "select-input-wrapper" => %w[pb-0],

    # Upstream renders a Sheet below `md` and this panel above it, so its
    # classes never have to describe a phone. Here there is one tree and the
    # sheet *is* this panel, so the mobile branch has to be said in CSS: the
    # container turns visible at upstream's `SIDEBAR_WIDTH_MOBILE`, and the
    # spacer that reserves the panel's width in the page stops reserving it,
    # because a sheet overlays the page rather than sitting beside it.
    # `z-50` and `shadow-lg` are `sheet-content`'s own (sheet.tsx:63) and the
    # slide classes beside them are too — those pass this spec unprefixed,
    # because they are upstream's strings. These two carry the mobile prefix
    # only because the same element is the desktop panel the rest of the time.
    "sidebar-container" => %w[
      group-data-[mobile=true]:flex group-data-[mobile=true]:w-(--sidebar-width-mobile)
      group-data-[mobile=true]:z-50 group-data-[mobile=true]:shadow-lg
    ],
    "sidebar-gap" => %w[group-data-[mobile=true]:w-0],

    # The two conditions upstream writes as a React prop on the sidebar menu
    # button's tooltip — `hidden={state !== "collapsed" || isMobile}`
    # (sidebar.tsx:541). Neither is knowable when the server renders, so here
    # they are classes reading the panel's own attributes. The tokens are this
    # port's, and exist in no TSX for that reason. See features/sidebar.md.
    "tooltip-content" => %w[group-data-[mobile=true]:hidden group-data-[state=expanded]:hidden],

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
