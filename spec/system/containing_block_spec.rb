# frozen_string_literal: true

require "spec_helper"

# `stacking_context_spec.rb` covers what paints *over* a floating layer. This
# covers where the layer *lands*, which is a separate hazard with a separate
# cause: `transform`, `filter` and `contain: paint` each make an element the
# containing block for its `position: fixed` descendants, so a fixed layer
# inside one is positioned against that box instead of the viewport.
#
# The Popover API is supposed to lift the content into the top layer and out of
# reach of all three. `decisions/todo.md` carried this as unreproduced for a
# while — assumed rather than measured. These measure it.
RSpec.describe "A floating layer inside a containing block", :js do
  # A local, not a constant: a constant in a describe block lands on Object.
  ancestors = %w[transform filter contain]

  before do
    visit_preview(:popover, :inside_containing_block)
    wait_for_stimulus
  end

  # Where the content sits relative to its own trigger, in viewport
  # coordinates. Reading both boxes at once matters: if the ancestor became the
  # containing block, the content moves and the trigger does not, so the gap
  # between them is what changes.
  def offset_from_trigger(name)
    page.evaluate_script(<<~JS)
      (() => {
        const trigger = document.querySelector("[data-testid='trigger-#{name}']").getBoundingClientRect()
        const content = document.querySelector("[data-testid='content-#{name}']").getBoundingClientRect()
        const centre = (box) => box.left + box.width / 2
        return {
          below: Math.round(content.top - trigger.bottom),
          offCentre: Math.round(centre(content) - centre(trigger))
        }
      })()
    JS
  end

  ancestors.each do |name|
    context "when the ancestor carries #{name}" do
      it "still lands under its trigger" do
        find("[data-testid='trigger-#{name}']").click
        expect(page).to have_css("[data-testid='content-#{name}']")

        offset = offset_from_trigger(name)

        # Below the trigger — `side_offset` defaults to 4 — and centred on it,
        # because `align` defaults to `:center`. Comparing left edges instead
        # would read a correctly centred panel as 80px out, which is what the
        # first draft of this example did.
        #
        # Generous bounds on purpose: the question is "positioned against the
        # viewport" versus "positioned against the ancestor", and those differ
        # by the ancestor's own offset on the page — far more than a few pixels.
        expect(offset["below"]).to be_between(0, 24)
        expect(offset["offCentre"].abs).to be <= 8
      end
    end
  end
end
