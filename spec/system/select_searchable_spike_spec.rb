# frozen_string_literal: true

require "spec_helper"
require "axe-rspec"

# SPIKE — delete with the previews it audits.
#
# The searchable select can be shaped three ways, and the choice is a markup
# decision this project would otherwise have to argue about. axe is already
# wired here, so it gets to answer instead.
#
# Each preview omits `data-controller` on the root, so no Stimulus connects and
# the layer renders visible. What is under audit is the ARIA shape alone — the
# classes, parts and components are the ones the gem already ships.
RSpec.describe "Searchable select — ARIA shapes", :js do
  # The same ruleset accessibility_spec.rb audits every family against.
  def audit
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  # A: the naive bolt-on — the input lands inside SelectContent, which already
  # carries `role="listbox"`, making a textbox a child of the listbox.
  it "A: search input nested inside the element that is the listbox" do
    visit_preview(:select, :spike_a_input_inside_listbox)

    audit
  end

  # B: `role="listbox"` moves to an inner list so the input is its sibling, but
  # the trigger keeps the `role="combobox"` our Radix port emits — two
  # combobox-ish elements in one widget.
  it "B: inner listbox, trigger still role=combobox" do
    visit_preview(:select, :spike_b_inner_list_combobox_trigger)

    audit
  end

  # C: as B, with the trigger reduced to a button announcing a popup, leaving
  # the input as the only combobox-ish element. Closest to upstream's aria
  # variant, and the only one that costs a divergence from our Radix markup.
  it "C: inner listbox, trigger is a plain button" do
    visit_preview(:select, :spike_c_inner_list_plain_trigger)

    audit
  end
end
