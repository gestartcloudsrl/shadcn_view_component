# frozen_string_literal: true

require "spec_helper"

# The three values upstream reads per box — the character, whether the box is
# active, and whether it draws the caret — and the one thing under them: a real
# input lying over the boxes, so the browser owns typing, paste, backspace and
# the arrows, and this owns painting.
#
# Typed rather than assigned. `input.value = …` is how the DOM changes a field;
# it is not how a person does, and this component is entirely about what
# happens between the two.
RSpec.describe "Input OTP", :js do
  let(:input) { "[data-slot=input-otp]" }
  let(:slot) { "[data-slot=input-otp-slot]" }

  def boxes
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(#{slot.to_json})].map((s) => ({
        char: s.querySelector("[data-shadcn--input-otp-target=char]").textContent,
        active: s.dataset.active === "true",
        caret: !s.querySelector("[data-shadcn--input-otp-target=caret]").hidden
      }))
    JS
  end

  def chars = boxes.map { |b| b["char"] }
  def active_index = boxes.index { |b| b["active"] }

  before do
    visit_preview(:input_otp)
    wait_for_stimulus
  end

  it "fills the boxes as the code is typed" do
    find(input).send_keys("123")

    expect(chars).to eq([ "1", "2", "3", "", "", "" ])
  end

  # The caret is drawn by the box, not by the input, whose own is transparent —
  # so "where am I typing" is a thing this component has to say for itself.
  it "marks the box the next character will go in, and draws a caret there" do
    find(input).send_keys("12")

    expect(active_index).to eq(2)
    expect(boxes[2]["caret"]).to be(true)
    expect(boxes.count { |b| b["caret"] }).to eq(1)
  end

  # A full code leaves the caret past the last box, and no box would be active
  # at all. The package clamps the selection so the last one stays lit
  # (input.tsx:432, 472); without that a finished code looks like an abandoned
  # one.
  it "keeps the last box lit when the code is complete", :aggregate_failures do
    find(input).send_keys("123456")

    expect(chars).to eq(%w[1 2 3 4 5 6])
    expect(active_index).to eq(5)
    # Lit, but no caret: the box is full, and a caret in a full box is a lie
    # about where the next character goes.
    expect(boxes[5]["caret"]).to be(false)
  end

  it "empties a box on backspace" do
    find(input).send_keys("123")
    find(input).send_keys(:backspace)

    expect(chars).to eq([ "1", "2", "", "", "", "" ])
    expect(active_index).to eq(2)
  end

  # No box is active while the field is not focused, which is upstream's rule
  # and the reason `isActive` reads `isFocused` first.
  it "lights nothing once the field is left" do
    find(input).send_keys("12")
    expect(active_index).to eq(2)

    page.execute_script("document.querySelector(#{input.to_json}).blur()")

    expect(page).to have_css("#{slot}[data-active=true]", count: 0)
  end

  # `onComplete` upstream. There is no markup for a callback, so this is an
  # event — an app decides whether that means submit.
  it "announces a finished code once" do
    page.execute_script(<<~JS)
      window.__completed = []
      document.addEventListener("shadcn--input-otp:complete", (e) => window.__completed.push(e.detail.value))
    JS

    find(input).send_keys("123456")

    expect(page.evaluate_script("window.__completed")).to eq([ "123456" ])
  end

  # The whole reason there is one input rather than six: a code arrives pasted
  # or from a message, in one piece.
  it "takes a whole code at once" do
    page.execute_script(<<~JS)
      const i = document.querySelector(#{input.to_json})
      i.focus()
      i.value = "987654"
      i.dispatchEvent(new Event("input", { bubbles: true }))
    JS

    expect(chars).to eq(%w[9 8 7 6 5 4])
  end

  # What makes a phone offer the code from a message and a password manager see
  # a field at all. None of it is decoration: an input that is hidden rather
  # than transparent is one neither of them will fill.
  it "is a real, fillable input under the boxes", :aggregate_failures do
    field = find(input, visible: :all)

    expect(field["autocomplete"]).to eq("one-time-code")
    expect(field["inputmode"]).to eq("numeric")
    expect(field["maxlength"]).to eq("6")

    style = page.evaluate_script(<<~JS)
      (() => {
        const s = getComputedStyle(document.querySelector(#{input.to_json}))
        return { opacity: s.opacity, colour: s.color, caret: s.caretColor,
                 pointer: s.pointerEvents, size: s.fontSize }
      })()
    JS

    expect(style["opacity"]).to eq("1")
    # The colour is the load-bearing one, and the only one this can check:
    # `caret-color: transparent` is upstream's declaration and worth carrying,
    # but `auto` computes to the text's colour — already transparent — so no
    # assertion here can tell the two apart.
    expect(style["colour"]).to eq("rgba(0, 0, 0, 0)")
    expect(style["caret"]).to eq("rgba(0, 0, 0, 0)")
    expect(style["pointer"]).to eq("all")
    # Sized to the boxes, so a native selection paints across them rather than
    # across a line of invisible text of some other height.
    expect(style["size"]).to eq("36px")
  end
end
