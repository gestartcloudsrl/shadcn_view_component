# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Checkbox", :js do
  before do
    visit_preview(:checkbox)
    wait_for_stimulus
  end

  it "toggles state, aria-checked and the hidden input together" do
    box = find("[data-slot=checkbox]", match: :first)

    expect(box["data-state"]).to eq("unchecked")
    expect(box["aria-checked"]).to eq("false")
    expect(page.evaluate_script("document.querySelector('input[name=terms]').checked")).to be(false)

    box.click

    expect(box["data-state"]).to eq("checked")
    expect(box["aria-checked"]).to eq("true")
    expect(page.evaluate_script("document.querySelector('input[name=terms]').checked")).to be(true)
  end

  # Radix mounts the tick only while checked; the server renders it hidden so
  # the markup is right without JavaScript, and the controller detaches it.
  it "mounts the indicator only while checked" do
    box = find("[data-slot=checkbox]", match: :first)

    expect(box).to have_no_css("[data-slot=checkbox-indicator]", visible: :all)

    box.click
    expect(box).to have_css("[data-slot=checkbox-indicator]")
  end

  it "renders a checked one already ticked" do
    box = all("[data-slot=checkbox]")[1]

    expect(box["data-state"]).to eq("checked")
    expect(box).to have_css("[data-slot=checkbox-indicator]")
  end

  it "ignores clicks when disabled" do
    box = all("[data-slot=checkbox]").last
    expect(box).to be_disabled

    page.execute_script(
      "document.querySelectorAll('[data-slot=checkbox]')[2].dispatchEvent(new MouseEvent('click', { bubbles: true }))"
    )

    expect(box["data-state"]).to eq("unchecked")
  end

  it "toggles from the keyboard" do
    box = find("[data-slot=checkbox]", match: :first)
    box.send_keys(:space)

    expect(box["data-state"]).to eq("checked")
  end
end

RSpec.describe "Switch", :js do
  before do
    visit_preview(:switch)
    wait_for_stimulus
  end

  it "toggles the switch and its thumb" do
    switch = find("[data-slot=switch]", match: :first)

    expect(switch["role"]).to eq("switch")
    expect(switch["aria-checked"]).to eq("false")

    switch.click

    expect(switch["data-state"]).to eq("checked")
    expect(switch["aria-checked"]).to eq("true")
    expect(switch.find("[data-slot=switch-thumb]")["data-state"]).to eq("checked")
    expect(page.evaluate_script("document.querySelector('input[name=airplane]').checked")).to be(true)
  end
end

RSpec.describe "RadioGroup", :js do
  before do
    visit_preview(:radio_group)
    wait_for_stimulus
  end

  def states = all("[data-slot=radio-group-item]").map { |item| item["data-state"] }

  it "starts on the value it was given" do
    expect(find("[data-slot=radio-group]")["role"]).to eq("radiogroup")
    expect(states).to eq(%w[unchecked checked unchecked])
    expect(page.evaluate_script("document.querySelector('input[name=plan]').value")).to eq("comfortable")
  end

  it "moves the selection on click and updates the hidden input" do
    all("[data-slot=radio-group-item]").first.click

    expect(states).to eq(%w[checked unchecked unchecked])
    expect(page.evaluate_script("document.querySelector('input[name=plan]').value")).to eq("default")
  end

  it "selects with the arrow keys, per the ARIA radio pattern" do
    all("[data-slot=radio-group-item]")[1].send_keys(:arrow_down)

    expect(states).to eq(%w[unchecked unchecked checked])

    press(:arrow_down)
    expect(states).to eq(%w[checked unchecked unchecked])
  end

  it "keeps a roving tabindex on the selected item" do
    expect(all("[data-slot=radio-group-item]").map { |i| i["tabindex"] }).to eq(%w[-1 0 -1])
  end
end

RSpec.describe "Toggle", :js do
  before do
    visit_preview(:toggle)
    wait_for_stimulus
  end

  it "flips aria-pressed and data-state" do
    toggle = find("[data-slot=toggle]", match: :first)

    expect(toggle["aria-pressed"]).to eq("false")
    expect(toggle["data-state"]).to eq("off")

    toggle.click

    expect(toggle["aria-pressed"]).to eq("true")
    expect(toggle["data-state"]).to eq("on")
  end

  # The browser already refuses to click a disabled button, so this checks the
  # other half: the controller's own guard, in case the event arrives anyway.
  it "leaves a disabled toggle alone" do
    toggle = all("[data-slot=toggle]").last
    expect(toggle).to be_disabled

    page.execute_script(
      "document.querySelectorAll('[data-slot=toggle]')[3].dispatchEvent(new MouseEvent('click', { bubbles: true }))"
    )

    expect(toggle["data-state"]).to eq("off")
  end
end

RSpec.describe "ToggleGroup", :js do
  before do
    visit_preview(:toggle_group)
    wait_for_stimulus
  end

  def group(index) = all("[data-slot=toggle-group]")[index]

  it "allows several at once in multiple mode" do
    items = group(0).all("[data-slot=toggle-group-item]")

    items[0].click
    items[1].click

    expect(items.map { |item| item["data-state"] }).to eq(%w[on on off])
  end

  it "allows only one in single mode" do
    items = group(1).all("[data-slot=toggle-group-item]")
    expect(items.map { |item| item["data-state"] }).to eq(%w[off on off])

    items[2].click
    expect(items.map { |item| item["data-state"] }).to eq(%w[off off on])
  end

  it "moves focus with the arrow keys" do
    items = group(0).all("[data-slot=toggle-group-item]")
    items[0].click
    items[0].send_keys(:arrow_right)

    expect(page.evaluate_script("document.activeElement.dataset.value")).to eq("italic")
  end
end
