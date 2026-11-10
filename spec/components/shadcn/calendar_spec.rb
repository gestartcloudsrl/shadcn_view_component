# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Calendar::Component do
  let(:painted) { Nokogiri::HTML5.fragment(rendered_content.to_s) }

  around { |example| travel_to(Date.new(2026, 8, 12)) { example.run } }

  # The name has to contain what the button shows — "3", not "03" — or a
  # voice-control user saying "click 3" has nothing to match. axe 4.14 checks
  # it (`label-content-name-mismatch`); upstream's day picker says "3rd".
  it "writes a single-digit day the way the button shows it" do
    render_inline(described_class.new(month: Date.new(2026, 8, 1)))

    expect(painted.at_css("button[data-day='2026-08-03']")["aria-label"]).to eq("Monday, August 3, 2026")
  end
end
