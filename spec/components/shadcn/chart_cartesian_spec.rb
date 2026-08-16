# frozen_string_literal: true

require "spec_helper"

# The frame — grid, axis, category labels, accessible name — and the three
# shapes drawn over it. What `Chart::Plot` computes is asserted in
# `chart_plot_spec.rb`; this is what reaches the DOM.
RSpec.describe Shadcn::Chart::Cartesian::Component, type: :component do
  let(:config) do
    { desktop: { label: "Desktop" }, mobile: { label: "Mobile" } }
  end
  let(:data) do
    { "January" => { desktop: 186, mobile: 80 }, "February" => { desktop: 305, mobile: 200 } }
  end

  def marks = page.all("[data-shadcn--chart-target=mark]", visible: :all)

  # A row's own header, then a cell per column — read apart, the way a screen
  # reader in table mode meets them.
  def cells(row) = row.all("th, td", visible: :all).map(&:text)

  # The four corner radii of a bar's outline, in the order the path draws them:
  # top-left, top-right, bottom-right, bottom-left.
  def radii(bar) = bar["d"].scan(/A (\S+)/).flatten.map(&:to_f)

  shared_examples "a chart with an axis" do
    before { render_inline(described_class.new(data:, config:, label: "Visitors")) }

    # The route to the numbers for anyone not using a pointer. A table rather
    # than a sentence: a screen reader enters it in table mode and moves by row
    # and column, where one long name can only be heard start to finish.
    it "puts every number in a table beside the graphic", :aggregate_failures do
      table = page.find("[data-slot=chart-table]", visible: :all)

      expect(table.find("caption", visible: :all).text).to eq("Visitors")
      expect(table.all("th[scope=col]", visible: :all).map(&:text)).to eq(%w[Desktop Mobile])
      # `th[scope=row]` and not a plain cell: it is what makes a screen reader
      # say "January" again as the reader moves along the row.
      expect(table.all("tbody th[scope=row]", visible: :all).map(&:text)).to eq(%w[January February])
      expect(table.all("tbody tr", visible: :all).map { |row| cells(row) })
        .to eq([ %w[January 186 80], %w[February 305 200] ])
    end

    # The graphic and the table must not both speak, and the graphic is the one
    # with nothing navigable in it.
    it "says nothing as a graphic", :aggregate_failures do
      svg = page.find("svg", visible: :all)

      expect(svg["aria-hidden"]).to eq("true")
      expect(svg["aria-label"]).to be_nil
    end

    # `aria-hidden` holds only while nothing inside can take focus — the pair is
    # what axe calls `aria-hidden-focus`, and it is what a keyboard cursor over
    # the marks would break.
    it "leaves nothing focusable inside the hidden graphic" do
      expect(page.all("svg [tabindex]", visible: :all)).to be_empty
    end

    it "draws a line per tick" do
      expect(page.all("line", visible: :all).size).to eq(Shadcn::Chart::Plot::TICKS + 1)
    end

    # A number in the right order and at the wrong height names the wrong line,
    # and reads as data rather than as a mistake. Within a few pixels, because
    # text hangs from its own baseline and the exact nudge is not the claim.
    it "sits each tick label on the line it names" do
      lines = page.all("line", visible: :all).map { |line| line["y1"].to_f }

      page.all("text", visible: :all).first(lines.size).each_with_index do |label, index|
        expect(label["y"].to_f).to be_within(4).of(lines[index])
      end
    end

    it "labels the axis and the categories" do
      expect(page.all("text", visible: :all).map(&:text))
        .to eq([ "0", "100", "200", "300", "400", "January", "February" ])
    end

    # The tooltip is filled from the DOM, so a mark carries the row it stands in
    # *and* the series it belongs to. A pie's two are the same word and a bar's
    # are not — this is the pair that made the controller need a fallback.
    it "tells a mark's category apart from its series" do
      mark = marks.first

      expect([ mark["data-label"], mark["data-name"], mark["data-display"] ])
        .to eq([ "January", "Desktop", "186" ])
    end
  end

  describe Shadcn::Chart::Bar::Component do
    it_behaves_like "a chart with an axis"

    it "draws one bar per series per category" do
      render_inline(described_class.new(data:, config:))

      expect(page.all("path", visible: :all).size).to eq(4)
    end

    # `radius={4}` at every corner, which is what upstream's grouped example
    # passes. A zero-radius arc is drawn as a straight line, so the four
    # radii in the path are the four corners.
    it "rounds every corner of a bar that stands on its own" do
      render_inline(described_class.new(data:, config:))

      expect(radii(page.first("path", visible: :all))).to eq([ 4.0, 4.0, 4.0, 4.0 ])
    end

    # The contract with `chart.tsx`: the container publishes `--color-<key>`
    # from its config and the shape asks for it by name, so a host restyling the
    # chart restyles this one too.
    it "fills each bar from the container's own custom property" do
      render_inline(described_class.new(data:, config:))

      expect(page.all("path", visible: :all).map { |bar| bar["fill"] }.uniq)
        .to contain_exactly("var(--color-desktop)", "var(--color-mobile)")
    end

    context "when the bars are stacked" do
      # The stack is the arithmetic `Plot` does; what this asserts is that the
      # option reaches it at all — with `stacked:` dropped on the way through,
      # four bars still render and every one of them is wrong.
      it "asks the plot for a stack" do
        render_inline(described_class.new(data:, config:, stacked: true))

        expect(page.all("path", visible: :all).map { |bar| bar["d"][/\A\S+ (\S+)/, 1] }.uniq.size).to eq(2)
      end

      # Upstream writes it as `radius={[4, 4, 0, 0]}`: a seam between two
      # segments is not the outside of anything, and rounding it leaves a
      # notch down the middle of the stack. Found in the gallery, not by a
      # spec — the HTML was exactly what the code meant to produce.
      it "rounds only the outside of the stack" do
        render_inline(described_class.new(data:, config:, stacked: true))

        bottom, top = page.all("path", visible: :all).first(2)

        expect([ radii(bottom), radii(top) ])
          .to eq([ [ 0.0, 0.0, 4.0, 4.0 ], [ 4.0, 4.0, 0.0, 0.0 ] ])
      end
    end
  end

  describe Shadcn::Chart::Line::Component do
    it_behaves_like "a chart with an axis"

    it "draws one polyline per series" do
      render_inline(described_class.new(data:, config:))

      expect(page.all("polyline", visible: :all).size).to eq(2)
    end

    it "strokes each line from the container's own custom property" do
      render_inline(described_class.new(data:, config:))

      expect(page.all("polyline", visible: :all).map { |line| line["stroke"] })
        .to eq([ "var(--color-desktop)", "var(--color-mobile)" ])
    end

    # A line's readings run edge to edge, so the labels naming the first and the
    # last sit on the edges too — and a label centred there is half outside the
    # viewBox, which an SVG clips. Reported by looking at the gallery: the last
    # month read "Jun".
    it "keeps the labels at both ends inside the box" do
      render_inline(described_class.new(data:, config:))

      months = page.all("text", visible: :all).last(2)

      expect(months.map { |month| month["text-anchor"] }).to eq(%w[start end])
    end

    # Four pixels is a target nobody can hold, so the dot a reader sees and the
    # dot a pointer hits are two circles. Only the second takes the events.
    it "gives each reading a target bigger than its dot", :aggregate_failures do
      render_inline(described_class.new(data:, config:))

      expect(page.all("circle", visible: :all).size).to eq(8)
      expect(marks.map { |mark| mark["r"].to_f }).to all(be > described_class::DOT)
    end
  end

  describe Shadcn::Chart::Area::Component do
    it_behaves_like "a chart with an axis"

    it "fills each area from the container's own custom property" do
      render_inline(described_class.new(data:, config:))

      expect(page.all("polygon", visible: :all).map { |area| area["fill"] })
        .to eq([ "var(--color-desktop)", "var(--color-mobile)" ])
    end

    it "closes each series against the baseline" do
      render_inline(described_class.new(data:, config:))

      corners = page.all("polygon", visible: :all).map { |area| area["points"].split.values_at(0, -1) }

      expect(corners.flatten.map { |corner| corner.split(",").last })
        .to all(eq(Shadcn::Chart::Plot.new(data:).baseline.round(2).to_s))
    end

    # A fill drawn after a line covers it, and SVG has no z-index to argue with.
    it "puts every fill under every line" do
      render_inline(described_class.new(data:, config:))

      drawn = page.all("polygon, polyline", visible: :all).map(&:tag_name)

      expect(drawn).to eq(%w[polygon polygon polyline polyline])
    end
  end

  # How many labels fit is the plot's arithmetic; drawing only those is the
  # component's half of it. Every fifth here, and the first always — an axis
  # starting at "Week 5" reads as though the data does.
  context "with more categories than the axis has room for" do
    let(:data) { (1..52).to_h { |week| [ "Week #{week}", { desktop: week } ] } }

    it "draws only the ones that fit", :aggregate_failures do
      render_inline(Shadcn::Chart::Line::Component.new(data:, config:))

      weeks = page.all("text", visible: :all).map(&:text).grep(/\AWeek/)

      expect(weeks.size).to eq(11)
      expect(weeks.first).to eq("Week 1")
    end
  end

  # An empty scope on a quiet week, which is a thing a host's data does. The
  # SVG still renders — the card around it should not collapse — and a table
  # would announce a name and then leave a reader in an empty grid.
  context "with nothing to draw" do
    let(:data) { {} }

    it "renders no table rather than an empty one", :aggregate_failures do
      render_inline(Shadcn::Chart::Bar::Component.new(data:, config:))

      expect(page).to have_no_css("[data-slot=chart-table]", visible: :all)
      expect(page.find("svg", visible: :all)["aria-hidden"]).to eq("true")
    end
  end

  # A series absent from a category is a gap in the Hash — a month where nothing
  # was sold, not a zero anyone typed — and it reaches both the axis and the
  # name.
  context "with a series missing from a category" do
    let(:data) { { "January" => { desktop: 186 }, "February" => { desktop: 305, mobile: 200 } } }

    it "reads it as nothing rather than as blank" do
      render_inline(Shadcn::Chart::Bar::Component.new(data:, config:))

      expect(cells(page.first("tbody tr", visible: :all))).to eq(%w[January 186 0])
    end
  end
end
