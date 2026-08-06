# frozen_string_literal: true

require "spec_helper"

# `position: fixed` escapes overflow clipping but never escapes a *stacking
# context*. A floating layer's `z-50` is scoped to the nearest positioned
# ancestor with a z-index, so a sibling with a higher one paints over it — and
# `sticky z-40` headers, `isolate` cards and anything with `opacity < 1` are
# ordinary Rails markup.
#
# The fix is the top layer: `showPopover()` promotes the element above every
# stacking context while leaving it in the DOM, so the Stimulus actions inside
# it keep working.
RSpec.describe "Floating layers inside a stacking context", :js do
  let(:content) { "[data-slot=popover-content]" }

  before do
    visit_preview(:popover, :inside_stacking_context)
    wait_for_stimulus
    find("[data-slot=popover-trigger]").click
    expect(page).to have_css(content)
  end

  # What the user actually cares about: is the layer clickable, or is something
  # else on top of it? `elementFromPoint` answers exactly that.
  def occluded?
    page.evaluate_script(<<~JS)
      (() => {
        const content = document.querySelector("[data-slot=popover-content]");
        const box = content.getBoundingClientRect();
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
        return !(hit === content || content.contains(hit));
      })()
    JS
  end

  it "is not covered by a sibling with a higher z-index" do
    expect(occluded?).to be(false)
  end

  # The positioned wrapper is what gets promoted; the content rides along inside
  # it, so its Stimulus actions stay bound.
  it "promotes the positioned wrapper to the top layer" do
    in_top_layer = page.evaluate_script(<<~JS)
      (() => {
        const wrapper = document.querySelector("[data-radix-popper-content-wrapper]");
        try { return wrapper.matches(":popover-open") } catch (e) { return false }
      })()
    JS

    expect(in_top_layer).to be(true)
  end

  it "still closes from its own controls, being in the top layer" do
    press(:escape)

    expect(page).to have_no_css(content)
  end

  it "is still positioned against its trigger" do
    aligned = page.evaluate_script(<<~JS)
      (() => {
        const t = document.querySelector("[data-slot=popover-trigger]").getBoundingClientRect();
        const c = document.querySelector("[data-slot=popover-content]").getBoundingClientRect();
        return Math.round(c.top - t.bottom);
      })()
    JS

    expect(aligned).to be_between(3, 5)
  end
end

RSpec.describe "A modal inside a stacking context", :js do
  let(:content) { "[data-slot=dialog-content]" }

  before do
    visit_preview(:dialog, :inside_stacking_context)
    wait_for_stimulus
    click_button "Open dialog"
    expect(page).to have_css(content)
  end

  def topmost_at_centre_of(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{selector}");
        const box = el.getBoundingClientRect();
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
        return hit === el || el.contains(hit) ? "self" : (hit?.dataset?.testid || hit?.dataset?.slot || hit?.tagName);
      })()
    JS
  end

  it "is not covered by a sibling with a higher z-index" do
    expect(topmost_at_centre_of("[data-slot=dialog-content]")).to eq("self")
  end

  # Both are fixed and both are promoted, so the order they are shown in decides
  # which sits on top. The content sitting on top is the example above; this one
  # is the other half — the overlay still covering everything else.
  it "keeps its overlay over the rest of the page" do
    covered = page.evaluate_script(<<~JS)
      (() => {
        const overlay = document.querySelector("[data-slot=dialog-overlay]");
        const hit = document.elementFromPoint(10, innerHeight - 10);
        return hit === overlay;
      })()
    JS
    expect(covered).to be(true)
  end

  it "still traps focus" do
    expect(page.evaluate_script("document.querySelector('#{content}').contains(document.activeElement)"))
      .to be(true)
  end

  it "still closes on Escape" do
    press(:escape)

    expect(page).to have_no_css(content)
  end
end
