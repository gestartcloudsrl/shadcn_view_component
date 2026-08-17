# frozen_string_literal: true

require "spec_helper"

# The one family answerable to Base UI rather than Radix. The behaviour is the
# searchable select's — a field that filters a listbox and keeps the caret — and
# what differs is the *names*: `data-open` where the rest of this gem writes
# `data-state="open"`, and the four unprefixed custom properties its own classes
# read.
RSpec.describe "Combobox", :js do
  let(:combobox) { "[data-slot=combobox]" }
  # By role rather than by slot: the field carries `input-group-control`,
  # because upstream renders it *as* an InputGroupInput and gives it no slot of
  # its own — which is what the rendered example says.
  let(:field) { "#{combobox} input[role=combobox]" }
  let(:content) { "[data-slot=combobox-content]" }
  let(:item) { "[data-slot=combobox-item]" }

  def options
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#{item}")]
        .filter((option) => !option.hidden)
        .map((option) => option.textContent.trim())
    JS
  end

  def highlighted
    page.evaluate_script("document.querySelector('#{item}[data-highlighted]')?.textContent.trim()")
  end

  def posted = page.evaluate_script("document.querySelector('#{combobox} input[type=hidden]')?.value")

  before do
    visit "/lookbook/preview/shadcn/combobox/default"
    wait_for_stimulus
  end

  describe "opening" do
    it "stays closed until the field is used", :aggregate_failures do
      expect(page).to have_no_css(content)
      expect(find(field)["aria-expanded"]).to eq("false")
    end

    # Base UI's own state attributes, which are what the panel's classes read —
    # `data-open:animate-in`, `data-closed:fade-out-0`. Every other family here
    # writes `data-state`, and this one may not.
    it "opens on focus, with the attributes its classes read", :aggregate_failures do
      find(field).click

      panel = find(content)
      expect(panel).to be_present
      expect(panel["data-open"]).to eq("")
      expect(panel["data-closed"]).to be_nil
      expect(find(field)["aria-expanded"]).to eq("true")
    end

    it "closes on Escape" do
      find(field).click
      find(field).send_keys(:escape)

      expect(page).to have_no_css(content)
    end
  end

  describe "filtering" do
    before { find(field).click }

    it "keeps what contains the query", :aggregate_failures do
      find(field).send_keys("ru")

      expect(options).to eq([ "Ruby", "Rust" ])
      expect(highlighted).to eq("Ruby")
    end

    # The empty state is shown by CSS alone — upstream's
    # `group-data-empty/combobox-content:flex` — so all the controller does is
    # mark the content, and this checks the mark *and* what a person sees.
    it "marks the panel empty when nothing matches", :aggregate_failures do
      find(field).send_keys("zzz")

      expect(options).to be_empty
      expect(find(content)["data-empty"]).to eq("")
      expect(find("[data-slot=combobox-empty]")).to be_visible
    end
  end

  describe "choosing" do
    before { find(field).click }

    it "puts the label in the field and the value in the form", :aggregate_failures do
      find("#{item}[data-value=rb]").click

      expect(find(field).value).to eq("Ruby")
      expect(posted).to eq("rb")
      expect(page).to have_no_css(content)
    end

    it "walks with the arrows and takes with Enter", :aggregate_failures do
      find(field).send_keys(:down, :down, :enter)

      expect(find(field).value).to eq("Python")
      expect(posted).to eq("py")
    end

    it "says what was taken" do
      page.execute_script(<<~JS)
        window.__taken = []
        document.addEventListener("shadcn--combobox:select", (e) => window.__taken.push(e.detail.value))
      JS

      find("#{item}[data-value=go]").click

      expect(page.evaluate_script("window.__taken")).to eq([ "go" ])
    end

    # The tick is the only thing that says which one was taken once the panel
    # has been closed and opened again.
    it "marks the chosen one when the panel comes back" do
      find("#{item}[data-value=go]").click
      find(field).click

      expect(page).to have_css("#{item}[data-value=go][aria-selected=true]")
    end
  end

  describe "clearing" do
    before do
      visit "/lookbook/preview/shadcn/combobox/with_clear"
      wait_for_stimulus
    end

    it "empties the field and the form together", :aggregate_failures do
      expect(find(field).value).to eq("Rails")

      find("[data-slot=combobox-clear]").click

      expect(find(field).value).to eq("")
      expect(posted).to eq("")
    end
  end

  # The panel is sized from Base UI's own custom properties — `w-(--anchor-width)`,
  # `max-w-(--available-width)` — which nothing else in this gem publishes, and
  # which are asked for rather than always emitted.
  it "publishes the variables its own classes read", :aggregate_failures do
    find(field).click

    published = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("#{content}")
        const style = getComputedStyle(panel)
        return { anchor: style.getPropertyValue("--anchor-width").trim(),
                 width: Math.round(panel.getBoundingClientRect().width),
                 field: Math.round(document.querySelector("#{field}").getBoundingClientRect().width) }
      })()
    JS

    expect(published["anchor"]).to match(/\A[\d.]+px\z/)
    expect(published["width"]).to be_within(2).of(published["field"])
  end

  it "points at the option it would take" do
    find(field).click
    find(field).send_keys(:down)

    pointed = find(field)["aria-activedescendant"]

    expect(find_by_id(pointed).text).to eq("Ruby")
  end

  # Multiple selection. What upstream settles — that the panel stays open across
  # choices and the field empties — is covered here; the two rules that are
  # *ours*, because Base UI's documentation is silent and Base UI is not
  # vendored, are marked as such in the example names.
  describe "multiple" do
    let(:chip) { "[data-slot=combobox-chip]" }

    def chips
      all(chip).map { |token| token.text.delete("\n").strip }
    end

    def posted_values
      page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#{combobox} input[type=hidden]")]
          .map((input) => input.value).filter((value) => value !== "")
      JS
    end

    before do
      visit "/lookbook/preview/shadcn/combobox/multiple"
      wait_for_stimulus
    end

    it "starts from what the server rendered", :aggregate_failures do
      expect(chips).to eq(%w[Ruby Go])
      expect(posted_values).to eq(%w[rb go])
    end

    # Both of these were shipped broken and found by looking at the rendered
    # box, not by reading the controller — the same way most of this family's
    # corrections were found.
    it "keeps the field last, whoever added the chip" do
      find(field).click
      find("#{item}[data-value=py]").click
      find("#{item}[data-value=rs]").click

      order = page.evaluate_script(<<~JS)
        [...document.querySelector("[data-slot=combobox-chips]").children]
          .filter((node) => node.tagName !== "TEMPLATE")
          .map((node) => node.dataset.slot || node.tagName.toLowerCase())
      JS

      # Inserting before the `<template>` instead put every new chip after the
      # field, with the server-rendered ones still before it.
      expect(order.last).to eq("combobox-chip-input")
      expect(order.count("combobox-chip")).to eq(4)
    end

    # The placeholder was this field's only name, so blanking it left a
    # `role="combobox"` with none — axe failed it as `label`, critical. The name
    # is read at render time and never touched again.
    it "keeps its name while the placeholder comes and goes", :aggregate_failures do
      expect(find(field)["aria-label"]).to eq("Add a language…")

      all("[data-slot=combobox-chip-remove]").each(&:click)

      expect(find(field)["aria-label"]).to eq("Add a language…")
    end

    it "drops the placeholder once there is a chip, and puts it back", :aggregate_failures do
      # Two chips are rendered by the server, so this one is wrong on load —
      # before anything is clicked.
      expect(find(field)["placeholder"]).to eq("")

      all("[data-slot=combobox-chip-remove]").each(&:click)

      expect(find(field)["placeholder"]).to eq("Add a language…")
    end

    it "adds a chip and keeps the panel open", :aggregate_failures do
      find(field).click
      find("#{item}[data-value=py]").click

      expect(chips).to eq(%w[Ruby Go Python])
      expect(posted_values).to eq(%w[rb go py])
      # Upstream's own multiple example shows both of these.
      expect(page).to have_css(content)
      expect(find(field).value).to eq("")
    end

    it "submits every chip under one bracketed name" do
      names = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#{combobox} input[type=hidden]")].map((input) => input.name)
      JS

      expect(names.uniq).to eq([ "project[languages][]" ])
    end

    it "keeps the parameter present when the last chip goes" do
      all("[data-slot=combobox-chip-remove]").each(&:click)

      expect(page).to have_no_css(chip)
      # The empty sentinel input, so the parameter still arrives and the
      # association is emptied rather than left alone.
      expect(page).to have_css("#{combobox} input[type=hidden][value='']", visible: :all)
    end

    it "takes a chip back off by its X", :aggregate_failures do
      within(first(chip)) { find("[data-slot=combobox-chip-remove]").click }

      expect(chips).to eq(%w[Go])
      expect(posted_values).to eq(%w[go])
    end

    it "ticks every chosen option in the list" do
      find(field).click

      ticked = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#{item}[aria-selected=true]")].map((option) => option.dataset.value)
      JS

      expect(ticked).to eq(%w[rb go])
    end

    # Ours: the documentation does not say whether re-taking a chosen option
    # deselects it. This keeps the list and the chips describing one set.
    it "puts an option back when it is taken twice (ours)", :aggregate_failures do
      find(field).click
      find("#{item}[data-value=rb]").click

      expect(chips).to eq(%w[Go])
      expect(posted_values).to eq(%w[go])
    end

    # Ours: no documented Backspace behaviour, and the X is a pointer target, so
    # this is the only way to undo a chip from the keyboard.
    it "removes the last chip on Backspace in an empty field (ours)" do
      find(field).send_keys(:backspace)

      expect(chips).to eq(%w[Ruby])
    end

    it "leaves the field's own text alone while there is any" do
      find(field).send_keys("ru")
      find(field).send_keys(:backspace)

      expect(chips).to eq(%w[Ruby Go])
      expect(find(field).value).to eq("r")
    end
  end
end
