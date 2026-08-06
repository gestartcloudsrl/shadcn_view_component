# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Popover", :js do
  let(:content) { "[data-slot=popover-content]" }

  before do
    visit_preview(:popover)
    wait_for_stimulus
  end

  it "opens and closes from the trigger" do
    trigger = find("[data-slot=popover-trigger]")

    expect(trigger["aria-haspopup"]).to eq("dialog")
    expect(page).to have_no_css(content)

    trigger.click
    expect(page).to have_css(content)
    expect(find(content)["role"]).to eq("dialog")
    expect(find("[data-slot=popover-trigger]")["aria-expanded"]).to eq("true")

    find("[data-slot=popover-trigger]").click
    expect(page).to have_no_css(content)
  end

  it "positions itself below the trigger with the requested offset" do
    find("[data-slot=popover-trigger]").click

    gap = page.evaluate_script(<<~JS)
      (() => {
        const t = document.querySelector("[data-slot=popover-trigger]").getBoundingClientRect();
        const c = document.querySelector("[data-slot=popover-content]").getBoundingClientRect();
        return Math.round(c.top - t.bottom);
      })()
    JS

    expect(gap).to be_between(3, 5) # sideOffset: 4
  end

  it "publishes the transform origin its animation classes read" do
    find("[data-slot=popover-trigger]").click

    origin = page.evaluate_script(<<~JS)
      document.querySelector("[data-slot=popover-content]")
        .style.getPropertyValue("--radix-popover-content-transform-origin")
    JS

    expect(origin).to eq("50% 0%")
  end

  it "records the side it resolved to" do
    find("[data-slot=popover-trigger]").click

    expect(find(content)["data-side"]).to eq("bottom")
  end

  it "closes on Escape and on an outside click" do
    find("[data-slot=popover-trigger]").click
    press(:escape)
    expect(page).to have_no_css(content)

    find("[data-slot=popover-trigger]").click
    click_outside
    expect(page).to have_no_css(content)
  end
end

RSpec.describe "Tooltip", :js do
  let(:content) { "[data-slot=tooltip-content]" }

  before do
    visit_preview(:tooltip)
    wait_for_stimulus
  end

  it "opens on hover and closes on leave" do
    expect(page).to have_no_css(content)

    find("[data-slot=tooltip-trigger]").hover
    expect(page).to have_css(content, text: "Add to library")

    click_outside # moves the pointer away from the trigger
    expect(page).to have_no_css(content)
  end

  it "opens on keyboard focus and describes the trigger while open" do
    page.execute_script("document.querySelector('[data-slot=tooltip-trigger]').focus()")

    expect(page).to have_css(content)
    expect(find("[data-slot=tooltip-trigger]")["aria-describedby"]).to eq(find(content)["id"])
    expect(find(content)["role"]).to eq("tooltip")
  end

  it "gives up the describedby link once closed" do
    page.execute_script("document.querySelector('[data-slot=tooltip-trigger]').focus()")
    expect(page).to have_css(content)

    page.execute_script("document.querySelector('[data-slot=tooltip-trigger]').blur()")
    expect(page).to have_no_css(content)
    expect(find("[data-slot=tooltip-trigger]")["aria-describedby"]).to be_nil
  end

  it "opens on its preferred side when there is room" do
    find("[data-slot=tooltip-trigger]").hover

    expect(find(content)["data-side"]).to eq("top")
  end

  it "flips to the other side when the preferred one has no room" do
    # Pin the trigger to the very top of the viewport, so `side: :top` cannot fit.
    page.execute_script(<<~JS)
      const trigger = document.querySelector("[data-slot=tooltip-trigger]");
      Object.assign(trigger.style, { position: "fixed", top: "0px", left: "200px" });
    JS

    find("[data-slot=tooltip-trigger]").hover

    expect(find(content)["data-side"]).to eq("bottom")
  end

  it "keeps the content inside the viewport" do
    find("[data-slot=tooltip-trigger]").hover

    inside = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector("[data-slot=tooltip-content]").getBoundingClientRect();
        return r.top >= 0 && r.left >= 0 &&
               r.bottom <= innerHeight && r.right <= innerWidth;
      })()
    JS

    expect(inside).to be(true)
  end

  it "never takes focus" do
    find("[data-slot=tooltip-trigger]").hover
    expect(page).to have_css(content)

    expect(page.evaluate_script("document.activeElement.dataset.slot")).not_to eq("tooltip-content")
  end
end
