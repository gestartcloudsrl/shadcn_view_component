# frozen_string_literal: true

require "spec_helper"

# The arithmetic recharts does in JavaScript, done in Ruby — so it is asserted
# here rather than through a browser, the same trade `Calendar::Month` makes.
RSpec.describe Shadcn::Chart::Pie::Component do
  let(:config) do
    { chrome: { label: "Chrome" }, safari: { label: "Safari" }, firefox: { label: "Firefox" } }
  end

  def slices = page.all("path", visible: :all)

  it "draws one slice per entry" do
    render_inline(described_class.new(data: { chrome: 275, safari: 200, firefox: 187 }, config:))

    expect(slices.size).to eq(3)
  end

  # A pie of what, exactly: a zero is not a slice, and a negative one is not a
  # share of anything.
  it "leaves out what cannot be a slice", :aggregate_failures do
    render_inline(described_class.new(data: { chrome: 275, safari: 0, firefox: -10 }, config:))

    expect(slices.size).to eq(1)
    expect(slices.first["fill"]).to eq("var(--color-chrome)")
  end

  # The fill is the contract with `chart.tsx`: the container publishes
  # `--color-<key>` from its config, and the slice asks for it by name.
  it "fills each slice from the container's own custom property" do
    render_inline(described_class.new(data: { chrome: 1, safari: 1 }, config:))

    expect(slices.map { |slice| slice["fill"] })
      .to eq([ "var(--color-chrome)", "var(--color-safari)" ])
  end

  # What a filtered scope hands back on a quiet week. A `role="img"` with no
  # name is what axe calls `svg-img-alt`, and there is nothing to name.
  context "with nothing to draw" do
    it "announces nothing rather than an unnamed image", :aggregate_failures do
      render_inline(described_class.new(data: {}, config:))

      svg = page.find("svg", visible: :all)

      expect(svg["aria-hidden"]).to eq("true")
      expect(svg["role"]).to be_nil
    end
  end

  context "with one entry" do
    # An arc whose two ends are the same point draws nothing at all, so a lone
    # slice has to be a circle instead — and a pie of one is what a filter
    # leaves behind, not a curiosity.
    it "draws a circle rather than an arc of 360 degrees", :aggregate_failures do
      render_inline(described_class.new(data: { chrome: 275 }, config:))

      path = slices.first["d"]
      expect(path).to start_with("M 125.0 4.0 A")
      expect(path.scan("A").size).to eq(2)
    end
  end

  context "with an inner radius" do
    it "draws the ring as an outer arc and an inner one", :aggregate_failures do
      render_inline(described_class.new(data: { chrome: 1, safari: 1 }, config:, inner_radius: 0.6))

      path = slices.first["d"]
      expect(path.scan("A").size).to eq(2)
      # 121 * 0.6, which is the hole rather than the rim.
      expect(path).to include("A 72.6 72.6")
    end
  end

  describe "what the tooltip will show" do
    it "carries the number, delimited" do
      render_inline(described_class.new(data: { chrome: 1275, safari: 200 }, config:))

      expect(slices.first["data-display"]).to eq("1,275")
    end

    it "carries the share instead when one was asked for", :aggregate_failures do
      render_inline(described_class.new(data: { chrome: 300, safari: 100 }, config:, percentage: true))

      expect(slices.map { |slice| slice["data-display"] }).to eq([ "75%", "25%" ])
    end

    it "falls back to the key when the config does not name it" do
      render_inline(described_class.new(data: { unknown_browser: 1 }, config:))

      expect(slices.first["data-label"]).to eq("Unknown browser")
    end
  end

  # `role="img"` makes everything inside presentational, so the name is the only
  # thing a screen reader gets — it has to be the whole chart. A slice cannot
  # carry its own: `aria-label` on a `<path>` with no role is prohibited, which
  # is how this first shipped and what axe caught.
  describe "the accessible name" do
    subject(:name) { page.find("svg", visible: :all)["aria-label"] }

    before do
      render_inline(described_class.new(data: { chrome: 275, safari: 200 }, config:, label: "Visitors"))
    end

    it "names the chart and every slice in it", :aggregate_failures do
      expect(name).to start_with("Visitors — ")
      expect(name).to include("Chrome: 275", "Safari: 200")
    end

    # No `<title>`: the browser draws one as a native tooltip on hover, over the
    # component's own — which is what a screenshot showed happening.
    it "carries no SVG title, which the browser would show as a tooltip of its own" do
      expect(page).to have_no_css("title", visible: :all)
    end
  end
end
