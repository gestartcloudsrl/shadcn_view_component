# frozen_string_literal: true

require "spec_helper"

# The half of a cartesian chart that is not a shape. recharts computes it in
# JavaScript from a mounted element's measured box; here it is arithmetic on a
# plain object, so it is asserted directly rather than through a browser — the
# same trade `Calendar::Month` and the pie's own geometry make.
RSpec.describe Shadcn::Chart::Plot do
  subject(:plot) { described_class.new(data:) }

  let(:data) do
    { "January" => { desktop: 186, mobile: 80 }, "February" => { desktop: 305, mobile: 200 } }
  end

  describe "#max" do
    # A reader's axis stops at a number a person would have chosen. The tallest
    # value is 305, and an axis topping out at 305 puts every tick on a fraction.
    it "rounds up to a number a person would have picked" do
      expect(plot.max).to eq(400)
    end

    context "when the bars are stacked" do
      subject(:plot) { described_class.new(data:, stacked: true) }

      # The tallest thing on screen is a whole stack, not its largest part —
      # 305 + 200, which does not fit under 400.
      it "measures the whole stack rather than its tallest part" do
        expect(plot.max).to eq(600)
      end
    end

    context "with nothing to draw" do
      let(:data) { {} }

      # Every coordinate divides by the maximum, and a chart of no data is what
      # a filtered scope hands back on a quiet week.
      it "stays a number that can be divided by" do
        expect(plot.max).to eq(1)
      end
    end
  end

  describe "#ticks" do
    it "spans zero to the maximum" do
      expect(plot.ticks).to eq([ 0, 100, 200, 300, 400 ])
    end
  end

  describe "#y_of" do
    it "puts zero on the baseline and the maximum at the top" do
      expect([ plot.y_of(0), plot.y_of(plot.max) ])
        .to eq([ plot.baseline, described_class::PADDING[:top] ])
    end

    # Half the value, half the height — the property every bar and every point
    # in this file rests on.
    it "is proportional between them" do
      expect(plot.y_of(plot.max / 2)).to eq((plot.baseline + described_class::PADDING[:top]) / 2)
    end
  end

  describe "#bars" do
    it "draws one per series per category" do
      expect(plot.bars.size).to eq(4)
    end

    it "carries the number it stands for, so the shape need not look it up" do
      expect(plot.bars.first).to include(category: "January", key: "desktop", value: 186)
    end

    it "keeps a category's bars inside its own band" do
      january, february = plot.bars.group_by { |bar| bar[:category] }.values

      expect(january.map { |bar| bar[:x] + bar[:width] }.max)
        .to be < february.map { |bar| bar[:x] }.min
    end

    it "stands them on the baseline" do
      expect(plot.bars.map { |bar| (bar[:y] + bar[:height]).round(2) })
        .to all(eq(plot.baseline.round(2)))
    end

    context "when the bars are stacked" do
      subject(:plot) { described_class.new(data:, stacked: true) }

      # Stacked means each sits on the one below, and the bottom one on the
      # baseline. Two bars that merely share an `x` are a chart drawn wrong.
      it "sits each on the one below it" do
        bottom, top = plot.bars.take(2)

        expect(top[:y] + top[:height]).to be_within(0.01).of(bottom[:y])
      end

      it "gives the whole stack one width" do
        expect(plot.bars.map { |bar| bar[:x] }.uniq.size).to eq(2)
      end
    end
  end

  describe "#points" do
    # A line's axis is a point scale, not a band one: upstream's own line and
    # area charts touch both edges of the plot, and a line inset by half a band
    # at each end is the tell that it was drawn on a bar's scale.
    it "runs from one edge of the plot to the other" do
      expect(plot.points(:desktop).map { |point| point[:x] })
        .to eq([ described_class::PADDING[:left], plot.width - described_class::PADDING[:right] ])
    end

    context "with a single reading" do
      let(:data) { { "January" => { desktop: 186 } } }

      # There is no "other edge" to reach, and a point scale of one divides by
      # zero getting there.
      it "puts it in the middle" do
        expect(plot.points(:desktop).first[:x])
          .to eq((described_class::PADDING[:left] + plot.plot_width / 2.0).round(2))
      end
    end

    it "reads the series whichever way it was spelled" do
      expect(plot.points("desktop")).to eq(plot.points(:desktop))
    end
  end

  describe "#label_every" do
    it "draws them all when they fit" do
      expect(plot.label_every).to eq(1)
    end

    context "with more categories than the axis has room for" do
      let(:data) { (1..52).to_h { |week| [ "Week #{week}", { desktop: week } ] } }

      # 52 labels of seven characters each need some 2,500px on an axis 518px
      # wide, so only every fifth is drawn. Without this they overlap into a
      # grey smear — recharts rotates them instead, which needs a measured box.
      it "skips enough of them to stop the collision" do
        expect(plot.label_every).to eq(5)
      end
    end
  end
end
