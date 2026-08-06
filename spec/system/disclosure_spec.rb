# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Accordion", :js do
  let(:items) { "[data-slot=accordion-item]" }

  def states = all(items, visible: :all).map { |item| item["data-state"] }

  before do
    visit_preview(:accordion)
    wait_for_stimulus
  end

  it "opens the item it was given" do
    expect(states).to eq(%w[open closed closed])
  end

  it "links the open trigger to its panel", :aggregate_failures do
    trigger = all("[data-slot=accordion-trigger]").first
    panel = find("[data-slot=accordion-content]", visible: true)

    expect(trigger["aria-expanded"]).to eq("true")
    expect(trigger["aria-controls"]).to eq(panel["id"])
    expect(panel["aria-labelledby"]).to eq(trigger["id"])
  end

  context "when another item is opened" do
    it "closes the one that was open, in single mode" do
      click_button "Is it styled?"

      expect(states).to eq(%w[closed open closed])
      expect(page).to have_text("It comes with default styles")
    end
  end

  context "when the open item's own trigger is clicked" do
    it "collapses it, leaving nothing open" do
      click_button "Is it accessible?"

      expect(states).to eq(%w[closed closed closed])
    end
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

  def trigger = find("[data-slot=collapsible-trigger]")

  before do
    visit_preview(:collapsible)
    wait_for_stimulus
  end

  it "starts closed, with the trigger saying so" do
    expect(trigger["aria-expanded"]).to eq("false")
    expect(page).to have_no_css(content)
  end

  context "when opened" do
    before { trigger.click }

    it "reveals the panel and marks the trigger expanded" do
      expect(page).to have_css(content)
      expect(page).to have_text("@radix-ui/colors")
      expect(trigger["aria-expanded"]).to eq("true")
    end

    it "points the trigger at the panel it controls" do
      expect(trigger["aria-controls"]).to eq(find(content)["id"])
    end

    it "closes again on a second click" do
      trigger.click

      expect(page).to have_no_css(content)
    end
  end
end

RSpec.describe "Tabs", :js do
  def selected = find("[data-slot=tabs-trigger][data-state=active]").text.strip

  before do
    visit_preview(:tabs)
    wait_for_stimulus
  end

  it "shows the panel for the selected tab only" do
    expect(selected).to eq("Account")
    expect(page).to have_text("Make changes to your account")
    expect(page).to have_no_text("Change your password")
  end

  it "wires each trigger to its panel", :aggregate_failures do
    trigger = find("[data-slot=tabs-trigger]", text: "Account")
    panel = find("[data-slot=tabs-content]", visible: true)

    expect(trigger["role"]).to eq("tab")
    expect(panel["role"]).to eq("tabpanel")
    expect(trigger["aria-controls"]).to eq(panel["id"])
    expect(panel["aria-labelledby"]).to eq(trigger["id"])
  end

  it "uses a roving tabindex" do
    tabindexes = all("[data-slot=tabs-trigger]").map { |trigger| trigger["tabindex"] }

    expect(tabindexes).to eq(%w[0 -1])
  end

  context "when another tab is clicked" do
    it "selects it and swaps the panel" do
      click_button "Password"

      expect(selected).to eq("Password")
      expect(page).to have_text("Change your password")
    end
  end

  context "when the arrow keys are used" do
    it "moves and activates in one step" do
      find("[data-slot=tabs-trigger]", text: "Account").send_keys(:arrow_right)

      expect(selected).to eq("Password")
      expect(page).to have_text("Change your password")

      press(:arrow_left)

      expect(selected).to eq("Account")
    end
  end
end
