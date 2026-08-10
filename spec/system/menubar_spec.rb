# frozen_string_literal: true

require "spec_helper"

# What is worth asserting is the bar. Everything inside a menu — the items, the
# submenu, the checkbox behaviour, the typeahead — is the dropdown's, driven by
# the dropdown's controller and covered in its spec; repeating it here would
# test the same code twice under another name.
#
# The bar is the part that has no counterpart there: one menu open at a time,
# arrows walking the names, and a menu already open turning the rest into things
# you merely hover to reach.
RSpec.describe "Menubar", :js do
  let(:trigger) { "[data-slot=menubar-trigger]" }
  let(:content) { "[data-slot=menubar-content]" }
  let(:sub_trigger) { "[data-slot=menubar-sub-trigger]" }
  let(:sub_content) { "[data-slot=menubar-sub-content]" }

  def triggers = all(trigger)

  def open_states = all(content, visible: :all).map { |panel| panel["data-state"] }

  def arrow(selector, direction)
    find(selector).send_keys(direction == :right ? :arrow_right : :arrow_left)
  end

  def point(element, event)
    page.execute_script(<<~JS, element)
      arguments[0].dispatchEvent(
        new PointerEvent(#{event.to_json}, { bubbles: false, pointerType: "mouse" })
      )
    JS
  end

  before do
    visit_preview(:menubar)
    wait_for_stimulus
  end

  it "opens a menu from its name, and only that one" do
    triggers.first.click

    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    expect(open_states.count("open")).to eq(1)
    expect(triggers.first["aria-expanded"]).to eq("true")
  end

  # The behaviour that makes a bar a bar rather than a row of dropdowns: with
  # one menu open, crossing another name switches to it. With none open,
  # crossing does nothing at all.
  it "switches on hover only while a menu is already open" do
    point(triggers[1], "pointerenter")
    expect(open_states.count("open")).to eq(0)

    triggers.first.click
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    point(triggers[1], "pointerenter")

    expect(page).to have_css("#{trigger}[data-state=open]", visible: :visible)
    expect(open_states.count("open")).to eq(1)
    expect(triggers[1]["data-state"]).to eq("open")
    expect(triggers.first["data-state"]).to eq("closed")
  end

  describe "from the keyboard" do
    # With the bar closed the arrows only move — Radix opens on the way past
    # only once something is already open, which the example above covers.
    it "walks the names with the arrows without opening anything" do
      triggers.first.send_keys(:arrow_right)

      expect(open_states.count("open")).to eq(0)

      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to eq(triggers[1].text.strip)
    end

    # Three menus, so "next" and "previous" are different answers — with two the
    # wrap-around cannot be told from an ordinary step.
    it "wraps at the end, which is Radix's default here and not the dropdown's" do
      triggers.last.send_keys(:arrow_right)

      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to eq(triggers.first.text.strip)
    end

    # The arrows keep working from inside an open panel, which is how the whole
    # bar is walked without closing anything on the way.
    it "moves to the next menu from inside an open one, and brings it open" do
      triggers.first.click
      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

      arrow("#{content}[data-state=open]", :right)

      expect(triggers[1]["data-state"]).to eq("open")
      expect(triggers.first["data-state"]).to eq("closed")
    end

    # Radix leaves the name unfocused on the way in so the panel can have the
    # focus uncontested (vendor/radix/ui/menubar.tsx:245-252). Focusing the trigger after
    # opening would take it straight back off, and the first Down would then
    # reopen rather than move.
    it "leaves the focus on the panel it opened, not on the name" do
      triggers.first.click
      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

      arrow("#{content}[data-state=open]", :right)
      # After the exit animation, not before it: the menu being replaced tears
      # down on its own timing, and reading straight away would miss a focus it
      # takes back late — which is the only way it could take it back at all.
      sleep 0.6

      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("menubar-content")
    end

    # The two halves Radix guards in one direction only, and which a guard
    # written one scope wider would swallow. On a sub-trigger only "next" is
    # spoken for — it opens the submenu — so "previous" must still walk the bar.
    it "walks backwards from a sub-trigger, whose Right is spoken for" do
      triggers.first.click
      expect(page).to have_css(sub_trigger, visible: :visible)

      arrow(sub_trigger, :left)

      expect(triggers.last["data-state"]).to eq("open")
    end

    # And inside a submenu it is "previous" that is spoken for — it closes the
    # submenu — so "next" must still walk the bar.
    it "walks forwards from inside a submenu, whose Left is spoken for" do
      triggers.first.click
      expect(page).to have_css(sub_trigger, visible: :visible)
      find(sub_trigger).hover
      expect(page).to have_css("#{sub_content}[data-state=open]", visible: :visible)

      arrow("#{sub_content} [data-slot=menubar-item]:first-child", :right)

      expect(triggers[1]["data-state"]).to eq("open")
    end
  end

  # Not a re-test of the dropdown's keyboard, but of the panel being where the
  # keyboard arrives at all. The panel is what the arrow keys, the typeahead and
  # Escape all listen on, so a panel that never takes focus has none of them —
  # and it takes focus only if it can be focused. Every other example here
  # dispatches its keys at an element it picked itself, so all of them stayed
  # green while an opened menu was, in fact, deaf.
  it "hands the keyboard to the panel it opens" do
    triggers.first.click
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    find("#{content}[data-state=open]").send_keys(:arrow_down)

    expect(page).to have_css("#{content} [data-slot=menubar-item][data-highlighted]", visible: :visible)
  end

  # One tab stop for the whole bar, moved by focus rather than left on every
  # name — otherwise tabbing through a page would stop at each menu.
  it "keeps a single tab stop" do
    triggers[1].click
    page.execute_script("document.querySelectorAll(#{trigger.to_json})[1].focus()")

    tabindexes = triggers.map { |t| t["tabindex"] }

    expect(tabindexes.count("0")).to eq(1)
    expect(triggers[1]["tabindex"]).to eq("0")
  end
end
