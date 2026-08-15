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
end
