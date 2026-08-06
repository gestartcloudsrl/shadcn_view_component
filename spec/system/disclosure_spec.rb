# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Accordion", :js do
  let(:items) { "[data-slot=accordion-item]" }

  def states = all(items, visible: :all).map { |item| item["data-state"] }

  before do
    visit_preview(:accordion)
    wait_for_stimulus
  end

  it "opens the item it was given and links trigger to panel" do
    expect(states).to eq(%w[open closed closed])

    trigger = all("[data-slot=accordion-trigger]").first
    panel = find("[data-slot=accordion-content]", visible: true)

    expect(trigger["aria-expanded"]).to eq("true")
    expect(trigger["aria-controls"]).to eq(panel["id"])
    expect(panel["aria-labelledby"]).to eq(trigger["id"])
  end

  it "opens one at a time in single mode" do
    click_button "Is it styled?"

    expect(states).to eq(%w[closed open closed])
    expect(page).to have_text("It comes with default styles")
  end

  it "collapses the open item when collapsible" do
    click_button "Is it accessible?"

    expect(states).to eq(%w[closed closed closed])
  end

  it "publishes the height the keyframes animate to" do
    click_button "Is it animated?"

    height = page.evaluate_script(<<~JS)
      document.querySelector("[data-slot=accordion-content][data-state=open]")
        .style.getPropertyValue("--radix-accordion-content-height")
    JS

    expect(height).to match(/\A\d+px\z/)
  end

  it "moves between triggers with the arrow keys" do
    all("[data-slot=accordion-trigger]").first.send_keys(:arrow_down)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to start_with("Is it styled?")

    press(:end)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to start_with("Is it animated?")

    press(:home)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to start_with("Is it accessible?")
  end
end

RSpec.describe "Collapsible", :js do
  let(:content) { "[data-slot=collapsible-content]" }

  before do
    visit_preview(:collapsible)
    wait_for_stimulus
  end

  it "toggles and keeps aria-expanded in step" do
    trigger = find("[data-slot=collapsible-trigger]")

    expect(trigger["aria-expanded"]).to eq("false")
    expect(page).to have_no_css(content)

    trigger.click
    expect(page).to have_css(content)
    expect(find("[data-slot=collapsible-trigger]")["aria-expanded"]).to eq("true")
    expect(page).to have_text("@radix-ui/colors")

    find("[data-slot=collapsible-trigger]").click
    expect(page).to have_no_css(content)
  end

  it "points the trigger at the panel it controls" do
    find("[data-slot=collapsible-trigger]").click

    expect(find("[data-slot=collapsible-trigger]")["aria-controls"]).to eq(find(content)["id"])
  end
end

RSpec.describe "Tabs", :js do
  before do
    visit_preview(:tabs)
    wait_for_stimulus
  end

  def selected = find("[data-slot=tabs-trigger][data-state=active]").text.strip

  it "shows the panel for the selected tab only" do
    expect(selected).to eq("Account")
    expect(page).to have_text("Make changes to your account")
    expect(page).to have_no_text("Change your password")
  end

  it "wires each trigger to its panel" do
    trigger = find("[data-slot=tabs-trigger]", text: "Account")
    panel = find("[data-slot=tabs-content]", visible: true)

    expect(trigger["role"]).to eq("tab")
    expect(panel["role"]).to eq("tabpanel")
    expect(trigger["aria-controls"]).to eq(panel["id"])
    expect(panel["aria-labelledby"]).to eq(trigger["id"])
  end

  it "switches on click" do
    click_button "Password"

    expect(selected).to eq("Password")
    expect(page).to have_text("Change your password")
  end

  it "uses a roving tabindex" do
    tabindexes = all("[data-slot=tabs-trigger]").map { |trigger| trigger["tabindex"] }

    expect(tabindexes).to eq(%w[0 -1])
  end

  it "moves and activates with the arrow keys" do
    find("[data-slot=tabs-trigger]", text: "Account").send_keys(:arrow_right)

    expect(selected).to eq("Password")
    expect(page).to have_text("Change your password")

    press(:arrow_left)
    expect(selected).to eq("Account")
  end
end
