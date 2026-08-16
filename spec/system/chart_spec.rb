# frozen_string_literal: true

require "spec_helper"

# The chart is drawn by the server and every number is already in the document,
# so most of what it does needs no browser: the geometry is asserted in
# `spec/components/shadcn/chart_plot_spec.rb` and the markup in the two chart
# component specs. What is left here is the tooltip — the half a static SVG
# cannot do — and one measurement of Chrome's accessibility tree, which is the
# question axe does not answer.
RSpec.describe "Chart", :js do
  let(:chart) { "[data-slot=chart]" }
  let(:tooltip) { "[data-slot=chart-tooltip]" }

  def hover(key)
    page.find("#{chart} path[data-key='#{key}']", visible: :all).hover
  end

  def tooltip_text
    page.find(tooltip, visible: :all).text.split("\n").reject(&:empty?)
  end

  before do
    visit "/lookbook/preview/shadcn/chart/default"
    wait_for_stimulus
  end

  it "is hidden until a slice is under the pointer", :aggregate_failures do
    expect(page).to have_no_css(tooltip)

    hover("safari")

    expect(page).to have_css(tooltip)
  end

  it "says what the slice says", :aggregate_failures do
    hover("safari")

    expect(tooltip_text).to eq([ "Safari", "200" ])
  end

  # The swatch takes the slice's own colour by name rather than a copy of it, so
  # a theme that repaints `--color-safari` repaints both. Both properties, not the style attribute as a whole: with only one of them
  # asserted, a mutation that reddens the fill and leaves the border alone goes
  # unnoticed.
  it "colours the indicator from the same custom property as the slice", :aggregate_failures do
    hover("safari")

    style = page.find("#{tooltip} div[style*='--color-bg']", visible: :all)["style"]

    expect(style).to include("--color-bg: var(--color-safari)")
    expect(style).to include("--color-border: var(--color-safari)")
  end

  it "follows the pointer to another slice" do
    hover("safari")
    hover("firefox")

    expect(tooltip_text).to eq([ "Firefox", "187" ])
  end

  it "goes away when the pointer leaves" do
    hover("safari")
    page.driver.browser.action.move_to_location(5, 5).perform

    expect(page).to have_no_css(tooltip)
  end

  # A tooltip that hangs out of the chart is what a caller's `overflow-hidden`
  # clips, and a card is exactly that.
  it "stays inside the chart it belongs to", :aggregate_failures do
    hover("chrome")

    inside = page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("#{chart}").getBoundingClientRect()
        const panel = document.querySelector("#{tooltip}").getBoundingClientRect()
        return { left: Math.round(panel.left - box.left), right: Math.round(box.right - panel.right),
                 top: Math.round(panel.top - box.top), bottom: Math.round(box.bottom - panel.bottom) }
      })()
    JS

    expect(inside["left"]).to be >= 0
    expect(inside["right"]).to be >= 0
    expect(inside["top"]).to be >= 0
  end

  # The one thing axe cannot answer: axe checks rules, and what matters here is
  # what a screen reader is actually handed. Chrome's own accessibility tree
  # says it — the same measurement the select's name uses.
  #
  # Two nodes carry the chart's name, and they say different things: the
  # graphic announces itself as something you can put the keyboard into, and
  # the table carries the numbers. What must not happen is the *data* arriving
  # twice — which is what the axis labels reaching the tree as loose text would
  # be, and what upstream's own chart does.
  context "with a screen reader on it" do
    let(:label) { "Visitors a month, by device" }

    def ax_nodes
      page.driver.browser.execute_cdp("Accessibility.enable")
      page.driver.browser.execute_cdp("Accessibility.getFullAXTree")["nodes"]
    end

    before do
      visit "/lookbook/preview/shadcn/chart/bar"
      wait_for_stimulus
    end

    it "hands the numbers over as a table", :aggregate_failures do
      nodes = ax_nodes
      # Minus the caption's own text nodes, which are how the table's name is
      # drawn rather than a second thing saying it.
      named = nodes.map { |node| node.dig("role", "value") if node.dig("name", "value") == label }
                   .compact - %w[StaticText InlineTextBox]

      expect(named).to eq(%w[application table])
      expect(nodes.map { |node| [ node.dig("role", "value"), node.dig("name", "value") ] })
        .to include([ "rowheader", "January" ], [ "cell", "186" ])
    end

    # The drawing is hidden, so an axis tick is a number on a screen and
    # nothing in the tree. Left exposed — which is what upstream does — a
    # reader meets "400 300 200 100 0 January February …" before reaching
    # anything that explains it.
    it "leaves the axis out of it" do
      expect(ax_nodes.map { |node| node.dig("name", "value") }).not_to include("400")
    end
  end

  # The other way to the tooltip, for someone who sees the chart and has no
  # pointer. Upstream's own shape: the surface takes the focus, and the arrows
  # walk the marks in the order they were drawn — every series of a category
  # before the next category.
  context "with a keyboard on it" do
    let(:graphic) { "#{chart} [data-slot=chart-bar]" }

    before do
      visit "/lookbook/preview/shadcn/chart/bar"
      wait_for_stimulus
    end

    it "walks the marks and says what each one says", :aggregate_failures do
      page.find(graphic, visible: :all).send_keys(:arrow_right)

      expect(tooltip_text).to eq([ "January", "Desktop", "186" ])

      page.find(graphic, visible: :all).send_keys(:arrow_right)

      expect(tooltip_text).to eq([ "January", "Mobile", "80" ])
    end

    # Clamped rather than wrapped: an edge you can feel is how you know the
    # series ended, where wrapping reads as a chart starting over.
    it "stops at the end instead of wrapping round" do
      page.find(graphic, visible: :all).send_keys(:home)
      2.times { page.find(graphic, visible: :all).send_keys(:arrow_left) }

      expect(tooltip_text).to eq([ "January", "Desktop", "186" ])
    end

    # Which end you enter by is the key you pressed: a left arrow means you
    # were reaching for the far end, the way a menu opened with ArrowUp starts
    # at its last item.
    it "enters from the far end when the first key is a left arrow" do
      page.find(graphic, visible: :all).send_keys(:arrow_left)

      expect(tooltip_text).to eq([ "June", "Mobile", "140" ])
    end

    it "goes to the end and back to the start" do
      page.find(graphic, visible: :all).send_keys(:end)

      expect(tooltip_text).to eq([ "June", "Mobile", "140" ])

      page.find(graphic, visible: :all).send_keys(:home)

      expect(tooltip_text).to eq([ "January", "Desktop", "186" ])
    end

    it "dismisses on Escape", :aggregate_failures do
      page.find(graphic, visible: :all).send_keys(:arrow_right)

      expect(page).to have_css(tooltip)

      page.find(graphic, visible: :all).send_keys(:escape)

      expect(page).to have_no_css(tooltip)
    end

    # A tooltip left behind on a chart nobody is looking at any more.
    it "goes away when the focus does" do
      page.find(graphic, visible: :all).send_keys(:arrow_right)
      page.find("body").click

      expect(page).to have_no_css(tooltip)
    end
  end

  # A pie's label and its series name are the same word; a bar's are the month
  # it stands in and the device it counts. This is the pair the controller's
  # fallback exists for, and the only place the two can be told apart.
  context "with an axis under the shape" do
    it "names the category and the series" do
      visit "/lookbook/preview/shadcn/chart/bar"
      wait_for_stimulus

      page.first("#{chart} path[data-key='mobile']", visible: :all).hover

      expect(tooltip_text).to eq([ "January", "Mobile", "80" ])
    end
  end

  context "when the share was asked for" do
    it "shows it where the count would be" do
      visit "/lookbook/preview/shadcn/chart/percentages"
      wait_for_stimulus

      hover("margin")

      expect(tooltip_text.last).to eq("24.9%")
    end
  end
end
