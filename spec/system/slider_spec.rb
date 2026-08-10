# frozen_string_literal: true

require "spec_helper"

# The values live in the DOM: each thumb's `aria-valuenow` *is* the value, and
# the range's edges, the wrappers' offsets and the hidden inputs are all derived
# from it. So these read that attribute rather than pixels — a slider asserted
# on geometry passes just as well when the number underneath is wrong, and the
# number is what a form submits.
RSpec.describe "Slider", :js do
  let(:sliders) { "[data-slot=slider]" }

  def single = all(sliders)[0]
  def range = all(sliders)[1]
  def disabled = all(sliders)[2]

  def values_of(slider)
    slider.all("[data-slot=slider-thumb]", visible: :all).map { |t| t["aria-valuenow"].to_i }
  end

  def edges_of(slider)
    page.evaluate_script(<<~JS, slider)
      (() => {
        const el = arguments[0].querySelector("[data-slot=slider-range]")
        return { left: el.style.left, right: el.style.right }
      })()
    JS
  end

  before do
    visit_preview(:slider)
    wait_for_stimulus
  end

  it "renders the value it was given, before anything is touched" do
    expect(values_of(single)).to eq([ 50 ])
    expect(values_of(range)).to eq([ 25, 75 ])
  end

  # Each thumb is its own control. A two-handled range is two things a screen
  # reader can land on and change, not one with two numbers.
  it "gives every thumb its own slider role and bounds" do
    thumb = range.all("[data-slot=slider-thumb]").first

    expect(thumb["role"]).to eq("slider")
    expect(thumb["aria-valuemin"]).to eq("0")
    expect(thumb["aria-valuemax"]).to eq("100")
    expect(thumb["aria-orientation"]).to eq("horizontal")
  end

  describe "from the keyboard" do
    it "moves by one step, and by ten for a page key" do
      thumb = single.find("[data-slot=slider-thumb]")

      thumb.send_keys(:arrow_right)
      expect(values_of(single)).to eq([ 51 ])

      thumb.send_keys(:page_up)
      expect(values_of(single)).to eq([ 61 ])

      thumb.send_keys(:page_down)
      expect(values_of(single)).to eq([ 51 ])
    end

    # Shift is the other ten — the same multiplier as a page key, which is
    # Radix's rule rather than two separate ones.
    it "moves by ten for a shifted arrow" do
      thumb = single.find("[data-slot=slider-thumb]")

      thumb.send_keys(%i[shift arrow_right])

      expect(values_of(single)).to eq([ 60 ])
    end

    it "goes to the ends with Home and End" do
      thumb = single.find("[data-slot=slider-thumb]")

      thumb.send_keys(:end)
      expect(values_of(single)).to eq([ 100 ])

      thumb.send_keys(:home)
      expect(values_of(single)).to eq([ 0 ])
    end

    # The constraint that makes a range a range. With `min_steps_between_thumbs:
    # 1` the lower thumb cannot reach the upper one, however hard it is pushed.
    it "keeps the thumbs a step apart" do
      lower = range.all("[data-slot=slider-thumb]").first

      20.times { lower.send_keys(:page_up) }

      expect(values_of(range)).to eq([ 74, 75 ])
    end

    it "does not move a disabled slider" do
      thumb = disabled.find("[data-slot=slider-thumb]", visible: :all)

      expect(thumb["tabindex"]).to eq("-1")

      thumb.send_keys(:arrow_right)
      expect(values_of(disabled)).to eq([ 30 ])
    end
  end

  describe "with a pointer" do
    # A press anywhere on the track is a value, which is what makes the whole
    # component a control rather than only its handle.
    it "moves the nearest thumb to where the track was pressed" do
      single.click(x: 0, y: 0)

      # The centre of a 0-100 slider, give or take the pixel the click landed on.
      expect(values_of(single).first).to be_within(3).of(50)

      single.click(x: (single.rect.width / 4).round, y: 0)
      expect(values_of(single).first).to be_within(4).of(75)
    end

    # Pressed near the *upper* thumb, deliberately. A press near the lower one
    # cannot tell "the nearest thumb" from "the first thumb" — they are the
    # same answer, and an example that cannot separate them says nothing.
    it "picks the nearer of two thumbs" do
      range.click(x: (range.rect.width / 3).round, y: 0)

      values = values_of(range)
      expect(values.first).to eq(25)
      expect(values.last).to be_within(5).of(83)
    end
  end

  # What a Rails form actually submits. shadcn's file renders no input — in
  # React the value is state — so this is the port's own, and it has to follow
  # the thumbs rather than the markup it started as.
  describe "the hidden inputs" do
    it "carries one value per thumb and keeps it current" do
      expect(single.find("input", visible: :all)["name"]).to eq("volume")
      expect(range.all("input", visible: :all).map { |i| i["name"] }).to eq(%w[range[] range[]])

      single.find("[data-slot=slider-thumb]").send_keys(:arrow_right)

      expect(single.find("input", visible: :all).value).to eq("51")
    end
  end

  # The filled part of the groove is one element with two edges, not a width —
  # which is how a two-thumb range stays a single element.
  it "fills the groove between the lowest and highest thumb" do
    expect(edges_of(range)).to eq("left" => "25%", "right" => "25%")

    range.all("[data-slot=slider-thumb]").first.send_keys(:home)

    expect(edges_of(range)).to eq("left" => "0%", "right" => "25%")
  end
end
