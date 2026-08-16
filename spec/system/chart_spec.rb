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
  # One node carries the chart's name and it is the table. If the graphic still
  # named itself there would be two, and a reader would meet the same data
  # twice: once as an image and once as rows.
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

    it "hands the numbers over as a table and nothing else", :aggregate_failures do
      nodes = ax_nodes
      # Minus the caption's own text nodes, which are how the table's name is
      # drawn rather than a second thing saying it.
      named = nodes.map { |node| node.dig("role", "value") if node.dig("name", "value") == label }
                   .compact - %w[StaticText InlineTextBox]

      expect(named).to eq([ "table" ])
      expect(nodes.map { |node| [ node.dig("role", "value"), node.dig("name", "value") ] })
        .to include([ "rowheader", "January" ], [ "cell", "186" ])
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
