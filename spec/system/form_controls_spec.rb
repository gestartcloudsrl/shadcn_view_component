# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Checkbox", :js do
  def box = find("[data-slot=checkbox]", match: :first)
  def terms_checked = page.evaluate_script("document.querySelector('input[name=terms]').checked")

  before do
    visit_preview(:checkbox)
    wait_for_stimulus
  end

  it "starts unchecked, in the markup and in the form" do
    expect(box["data-state"]).to eq("unchecked")
    expect(box["aria-checked"]).to eq("false")
    expect(terms_checked).to be(false)
  end

  # Radix mounts the tick only while checked; the server renders it hidden so
  # the markup is right without JavaScript, and the controller detaches it.
  it "mounts the indicator only while checked" do
    expect(box).to have_no_css("[data-slot=checkbox-indicator]", visible: :all)
  end

  context "when clicked" do
    before { box.click }

    it "checks state, aria-checked and the hidden input together" do
      expect(box["data-state"]).to eq("checked")
      expect(box["aria-checked"]).to eq("true")
      expect(terms_checked).to be(true)
    end

    it "mounts the indicator" do
      expect(box).to have_css("[data-slot=checkbox-indicator]")
    end
  end

  context "when the keyboard is used instead" do
    it "toggles on Space" do
      box.send_keys(:space)

      expect(box["data-state"]).to eq("checked")
    end
  end

  context "with a checked default" do
    it "renders already ticked" do
      checked = all("[data-slot=checkbox]")[1]

      expect(checked["data-state"]).to eq("checked")
      expect(checked).to have_css("[data-slot=checkbox-indicator]")
    end
  end

  context "when disabled" do
    it "ignores a click that arrives anyway" do
      disabled = all("[data-slot=checkbox]").last
      expect(disabled).to be_disabled

      page.execute_script(
        "document.querySelectorAll('[data-slot=checkbox]')[2].dispatchEvent(new MouseEvent('click', { bubbles: true }))"
      )

      expect(disabled["data-state"]).to eq("unchecked")
    end
  end
end

RSpec.describe "Switch", :js do
  def switch = find("[data-slot=switch]", match: :first)

  before do
    visit_preview(:switch)
    wait_for_stimulus
  end

  it "starts off, with the switch role", :aggregate_failures do
    expect(switch["role"]).to eq("switch")
    expect(switch["aria-checked"]).to eq("false")
  end

  context "when clicked" do
    before { switch.click }

    it "moves the switch, its thumb and the hidden input together" do
      expect(switch["data-state"]).to eq("checked")
      expect(switch["aria-checked"]).to eq("true")
      expect(switch.find("[data-slot=switch-thumb]")["data-state"]).to eq("checked")
      expect(page.evaluate_script("document.querySelector('input[name=airplane]').checked")).to be(true)
    end
  end
end

RSpec.describe "RadioGroup", :js do
  def states = all("[data-slot=radio-group-item]").map { |item| item["data-state"] }
  def plan = page.evaluate_script("document.querySelector('input[name=plan]').value")

  before do
    visit_preview(:radio_group)
    wait_for_stimulus
  end

  it "starts on the value it was given" do
    expect(find("[data-slot=radio-group]")["role"]).to eq("radiogroup")
    expect(states).to eq(%w[unchecked checked unchecked])
    expect(plan).to eq("comfortable")
  end

  it "keeps a roving tabindex on the selected item" do
    expect(all("[data-slot=radio-group-item]").map { |item| item["tabindex"] }).to eq(%w[-1 0 -1])
  end

  context "when another item is clicked" do
    it "moves the selection and the hidden input" do
      all("[data-slot=radio-group-item]").first.click

      expect(states).to eq(%w[checked unchecked unchecked])
      expect(plan).to eq("default")
    end
  end

  context "when the arrow keys are used" do
    it "selects as it moves, per the ARIA radio pattern" do
      all("[data-slot=radio-group-item]")[1].send_keys(:arrow_down)
      expect(states).to eq(%w[unchecked unchecked checked])

      press(:arrow_down)

      expect(states).to eq(%w[checked unchecked unchecked])
    end
  end
end

RSpec.describe "Toggle", :js do
  def toggle = find("[data-slot=toggle]", match: :first)

  before do
    visit_preview(:toggle)
    wait_for_stimulus
  end

  it "starts off", :aggregate_failures do
    expect(toggle["aria-pressed"]).to eq("false")
    expect(toggle["data-state"]).to eq("off")
  end

  context "when clicked" do
    it "flips aria-pressed and data-state together" do
      toggle.click

      expect(toggle["aria-pressed"]).to eq("true")
      expect(toggle["data-state"]).to eq("on")
    end
  end

  # The browser already refuses to click a disabled button, so this checks the
  # other half: the controller's own guard, in case the event arrives anyway.
  context "when disabled" do
    it "ignores a click that arrives anyway" do
      disabled = all("[data-slot=toggle]").last
      expect(disabled).to be_disabled

      page.execute_script(
        "document.querySelectorAll('[data-slot=toggle]')[3].dispatchEvent(new MouseEvent('click', { bubbles: true }))"
      )

      expect(disabled["data-state"]).to eq("off")
    end
  end
end

RSpec.describe "ToggleGroup", :js do
  def group(index) = all("[data-slot=toggle-group]")[index]

  before do
    visit_preview(:toggle_group)
    wait_for_stimulus
  end

  context "when the group is in multiple mode" do
    it "allows several at once" do
      items = group(0).all("[data-slot=toggle-group-item]")

      items[0].click
      items[1].click

      expect(items.map { |item| item["data-state"] }).to eq(%w[on on off])
    end

    it "moves focus with the arrow keys" do
      items = group(0).all("[data-slot=toggle-group-item]")
      items[0].click

      items[0].send_keys(:arrow_right)

      expect(page.evaluate_script("document.activeElement.dataset.value")).to eq("italic")
    end
  end

  context "when the group is in single mode" do
    it "allows only one" do
      items = group(1).all("[data-slot=toggle-group-item]")
      expect(items.map { |item| item["data-state"] }).to eq(%w[off on off])

      items[2].click

      expect(items.map { |item| item["data-state"] }).to eq(%w[off off on])
    end
  end
end
