# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Popover", :js do
  let(:content) { "[data-slot=popover-content]" }

  def trigger = find("[data-slot=popover-trigger]")

  before do
    visit_preview(:popover)
    wait_for_stimulus
  end

  it "starts closed, with a dialog-haspopup trigger" do
    expect(trigger["aria-haspopup"]).to eq("dialog")
    expect(page).to have_no_css(content)
  end

  context "when opened from the trigger" do
    before do
      trigger.click
      expect(page).to have_css(content)
    end

    it "exposes a dialog and marks the trigger expanded", :aggregate_failures do
      expect(find(content)["role"]).to eq("dialog")
      expect(trigger["aria-expanded"]).to eq("true")
    end

    it "positions itself below the trigger with the requested offset" do
      gap = page.evaluate_script(<<~JS)
        (() => {
          const t = document.querySelector("[data-slot=popover-trigger]").getBoundingClientRect();
          const c = document.querySelector("[data-slot=popover-content]").getBoundingClientRect();
          return Math.round(c.top - t.bottom);
        })()
      JS

      expect(gap).to be_between(3, 5) # sideOffset: 4
    end

    it "records the side it resolved to" do
      expect(find(content)["data-side"]).to eq("bottom")
    end

    it "publishes the transform origin its animation classes read" do
      origin = page.evaluate_script(<<~JS)
        document.querySelector("[data-slot=popover-content]")
          .style.getPropertyValue("--radix-popover-content-transform-origin")
      JS

      expect(origin).to eq("50% 0%")
    end

    it "closes from the trigger again" do
      trigger.click

      expect(page).to have_no_css(content)
    end

    it "closes on Escape" do
      press(:escape)

      expect(page).to have_no_css(content)
    end

    it "closes on an outside click" do
      click_outside

      expect(page).to have_no_css(content)
    end
  end
end

RSpec.describe "Tooltip", :js do
  let(:content) { "[data-slot=tooltip-content]" }

  def trigger = find("[data-slot=tooltip-trigger]")
  def focus_trigger = page.execute_script("document.querySelector('[data-slot=tooltip-trigger]').focus()")

  before do
    visit_preview(:tooltip)
    wait_for_stimulus
  end

  it "starts closed" do
    expect(page).to have_no_css(content)
  end

  context "when hovered" do
    before do
      trigger.hover
      expect(page).to have_css(content)
    end

    it "shows the tip" do
      expect(page).to have_css(content, text: "Add to library")
    end

    it "opens on its preferred side when there is room" do
      expect(find(content)["data-side"]).to eq("top")
    end

    it "keeps the content inside the viewport" do
      inside = page.evaluate_script(<<~JS)
        (() => {
          const r = document.querySelector("[data-slot=tooltip-content]").getBoundingClientRect();
          return r.top >= 0 && r.left >= 0 &&
                 r.bottom <= innerHeight && r.right <= innerWidth;
        })()
      JS

      expect(inside).to be(true)
    end

    # Reported from the gallery: no triangle. The arrow was in the markup and had
    # been since the port, so nothing that reads HTML could see it — it was an
    # inline `<span>`, and `size-2.5` does not apply to one, so it was 10px of
    # intent and a 0px box. Upstream's is an `<svg>`, which takes a width
    # because a replaced element does.
    #
    # Nothing positioned it either: Radix places the arrow through Popper, and
    # `popper.js` did not know it existed, so even sized it would have sat in
    # the text flow after the label.
    it "draws an arrow, with a box and outside the panel it points from", :aggregate_failures do
      box = page.evaluate_script(<<~JS)
        (() => {
          const c = document.querySelector("[data-slot=tooltip-content]")
          const a = c.querySelector("[data-slot=tooltip-arrow]")
          const cr = c.getBoundingClientRect(), ar = a.getBoundingClientRect()
          return { w: Math.round(ar.width), h: Math.round(ar.height),
                   below: Math.round(ar.bottom - cr.bottom),
                   centred: Math.abs((ar.left + ar.width / 2) - (cr.left + cr.width / 2)) < 2 }
        })()
      JS

      expect(box["w"]).to be > 0
      expect(box["h"]).to be > 0
      # Placed on the tooltip's own side — this one opens on top, so the arrow
      # hangs below it — and pointed at the middle of the trigger.
      expect(box["below"]).to be > 0
      expect(box["centred"]).to be(true)
    end

    # And the panel stands clear of the trigger by the arrow's own height, which
    # is what makes room for it. Radix folds that into the offset —
    # `offset({ mainAxis: sideOffset + arrowHeight })` — which is why shadcn's
    # `sideOffset = 0` (tooltip.tsx:47) still leaves a gap. Without it the panel
    # sits flush and the arrow lies across the thing it points at, which is how
    # this looked when it was reported.
    it "stands off the trigger by the height of its own arrow", :aggregate_failures do
      gap = page.evaluate_script(<<~JS)
        (() => {
          const c = document.querySelector("[data-slot=tooltip-content]")
          const a = c.querySelector("[data-slot=tooltip-arrow]")
          const t = document.querySelector("[data-slot=tooltip-trigger]")
          const cr = c.getBoundingClientRect(), ar = a.getBoundingClientRect()
          return { clear: Math.round(t.getBoundingClientRect().top - cr.bottom),
                   arrowH: Math.round(ar.height) }
        })()
      JS

      expect(gap["arrowH"]).to be > 0
      expect(gap["clear"]).to be_within(1).of(gap["arrowH"])
    end

    it "never takes focus" do
      expect(page.evaluate_script("document.activeElement.dataset.slot")).not_to eq("tooltip-content")
    end

    it "closes when the pointer leaves" do
      click_outside # moves the pointer away from the trigger

      expect(page).to have_no_css(content)
    end
  end

  context "when the preferred side has no room" do
    it "flips to the other side" do
      # Pin the trigger to the very top of the viewport, so `side: :top` cannot fit.
      page.execute_script(<<~JS)
        const trigger = document.querySelector("[data-slot=tooltip-trigger]");
        Object.assign(trigger.style, { position: "fixed", top: "0px", left: "200px" });
      JS

      trigger.hover

      expect(find(content)["data-side"]).to eq("bottom")
    end
  end

  # The four sides, on the preview built for them. `side:` belongs to the root:
  # passed to `with_tooltip_content` it is swallowed into the content's
  # attributes and quietly does nothing, which is how the sides preview shipped
  # asking for `top` four times and looking, correctly, identical. Nothing here
  # could see it — a keyword that lands in the attribute splat is valid Ruby,
  # valid HTML, and invisible to every spec that reads the DOM for what it
  # expected rather than for what was asked.
  context "when a side is asked for" do
    before do
      visit_preview(:tooltip, :sides)
      wait_for_stimulus
    end

    %w[Top Right Bottom Left].each do |label|
      it "opens on the #{label.downcase} and stands clear of the trigger" do
        find("[data-slot=tooltip-trigger]", text: label).hover
        expect(page).to have_css(content)

        measured = page.evaluate_script(<<~JS)
          (() => {
            const c = [...document.querySelectorAll("[data-slot=tooltip-content]")].find(e => !e.hidden)
            const t = c.closest("[data-slot=tooltip]").querySelector("[data-slot=tooltip-trigger]")
            const cr = c.getBoundingClientRect(), tr = t.getBoundingClientRect()
            const side = c.dataset.side
            const clear = side === "top" ? tr.top - cr.bottom
                        : side === "bottom" ? cr.top - tr.bottom
                        : side === "left" ? tr.left - cr.right
                        : cr.left - tr.right
            const a = c.querySelector("[data-slot=tooltip-arrow]")
            const ar = a.getBoundingClientRect()
            // How far the arrow reaches past the panel, on the edge it belongs to.
            const past = side === "top" ? ar.bottom - cr.bottom
                       : side === "bottom" ? cr.top - ar.top
                       : side === "left" ? ar.right - cr.right
                       : cr.left - ar.left
            return { side, clear: Math.round(clear),
                     arrow: [ Math.round(ar.width), Math.round(ar.height) ],
                     past: Math.round(past) }
          })()
        JS

        expect(measured["side"]).to eq(label.downcase)
        expect(measured["clear"]).to be > 0
        # The arrow has a box and it leans out of the panel towards the trigger.
        # Without this the left and right arrows spun about the wrong origin and
        # landed off their own edge, which four green examples did not notice.
        expect(measured["arrow"]).to all(be > 0)
        expect(measured["past"]).to be > 0
      end
    end
  end

  context "when focused from the keyboard" do
    before do
      focus_trigger
      expect(page).to have_css(content)
    end

    it "opens and describes the trigger", :aggregate_failures do
      expect(trigger["aria-describedby"]).to eq(find(content)["id"])
      expect(find(content)["role"]).to eq("tooltip")
    end

    it "gives up the describedby link once closed" do
      page.execute_script("document.querySelector('[data-slot=tooltip-trigger]').blur()")

      expect(page).to have_no_css(content)
      expect(trigger["aria-describedby"]).to be_nil
    end
  end
end
