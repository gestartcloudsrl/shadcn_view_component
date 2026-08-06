# frozen_string_literal: true

require "spec_helper"

RSpec.describe "theming" do
  describe ShadcnViewComponent::Themes do
    it "carries every palette shadcn ships" do
      expect(described_class::ALL.size).to eq(24)
      expect(described_class.names).to include("neutral", "zinc", "mauve", "blue", "rose")
    end

    it "separates the base greys from the accent palettes" do
      expect(described_class::BASE_COLORS.map { |t| t[:name] })
        .to eq(%w[neutral stone zinc mauve olive mist taupe])
      expect(described_class::ACCENTS).not_to be_empty
      expect(described_class::BASE_COLORS + described_class::ACCENTS).to match_array(described_class::ALL)
    end

    it "gives the base colours a complete token set for both modes" do
      described_class::BASE_COLORS.each do |theme|
        expect(theme[:light]).to include("background", "foreground", "primary", "radius"),
                                 "#{theme[:name]} is missing a light token"
        expect(theme[:dark]).to include("background", "foreground", "primary"),
                                "#{theme[:name]} is missing a dark token"
      end
    end

    # Accent palettes are overlays: they redefine only what they change and let
    # the rest fall through to `:root`, which is why dropping one onto <body>
    # recolours an app without restating the greys.
    it "gives the accents a partial overlay built around primary" do
      described_class::ACCENTS.each do |theme|
        expect(theme[:light]).to include("primary", "primary-foreground"),
                                 "#{theme[:name]} does not set a primary"
        expect(theme[:light].keys).not_to include("background"),
                                          "#{theme[:name]} unexpectedly redefines background"
      end
    end

    it "looks palettes up by name" do
      expect(described_class.find("zinc")[:title]).to eq("Zinc")
      expect(described_class.exists?("zinc")).to be(true)
      expect(described_class.exists?("nope")).to be(false)
    end
  end

  describe "the generated stylesheet" do
    subject(:css) do
      Pathname(__dir__).join("../../../app/assets/stylesheets/shadcn-themes.css").read
    end

    it "defines a class and a data-attribute selector for every palette" do
      ShadcnViewComponent::Themes.names.each do |name|
        expect(css).to include(".theme-#{name},\n[data-shadcn-theme=\"#{name}\"] {")
        expect(css).to include(".dark .theme-#{name},\n.dark[data-shadcn-theme=\"#{name}\"] {")
      end
    end

    it "matches the vendored registry values" do
      zinc = ShadcnViewComponent::Themes.find("zinc")

      expect(css).to include("--primary: #{zinc[:light]['primary']};")
      expect(css).to include("--primary: #{zinc[:dark]['primary']};")
    end
  end

  describe Shadcn::ModeToggle::Component do
    before { render_inline(described_class.new) }

    it "wraps the control in the theme controller" do
      expect(root["data-controller"]).to eq("shadcn--theme")
      expect(root["data-slot"]).to eq("mode-toggle")
    end

    it "offers light, dark and system" do
      modes = Nokogiri::HTML5.fragment(rendered_content)
                             .css("[data-slot=dropdown-menu-item]")
                             .map { |item| item["data-mode"] }

      expect(modes).to eq(%w[light dark system])
    end

    it "keeps the dropdown's own actions alongside the theme one" do
      item = Nokogiri::HTML5.fragment(rendered_content).at_css("[data-mode=dark]")

      expect(item["data-action"]).to include("click->shadcn--theme#setMode")
      expect(item["data-action"]).to include("click->shadcn--dropdown-menu#select")
      # The dropdown's action must appear once, not once per merge.
      expect(item["data-action"].scan("shadcn--dropdown-menu#select").size).to eq(1)
    end

    it "renders the sun and moon that cross-fade on .dark" do
      expect(rendered_content).to include("lucide-sun")
      expect(rendered_content).to include("lucide-moon")
      expect(rendered_content).to include("Toggle theme")
    end

    # The upstream example is vendored alongside the components it uses, so the
    # icon classes stay pinned to it the way the registry components are.
    it "uses the icon classes from mode-toggle.tsx" do
      tsx = Pathname(__dir__).join("../../../vendor/shadcn/examples/mode-toggle.tsx").read

      expect(tsx).to include(described_class::SUN_CLASSES)
      expect(tsx).to include(described_class::MOON_CLASSES)
    end
  end

  describe Shadcn::ModeSwitcher::Component do
    it "renders a single button bound to the toggle action" do
      render_inline(described_class.new)
      button = Nokogiri::HTML5.fragment(rendered_content).at_css("[data-slot=button]")

      expect(root["data-controller"]).to eq("shadcn--theme")
      expect(button["data-action"]).to include("shadcn--theme#toggle")
      expect(button["data-size"]).to eq("icon")
    end
  end

  describe Shadcn::ThemeSelector::Component do
    it "lists the base colours by default" do
      render_inline(described_class.new)
      values = Nokogiri::HTML5.fragment(rendered_content)
                              .css("[data-slot=select-item]")
                              .map { |item| item["data-value"] }

      expect(values).to eq(ShadcnViewComponent::Themes::BASE_COLORS.map { |t| t[:name] })
    end

    it "marks the current palette and labels the trigger with it" do
      render_inline(described_class.new(value: "zinc"))
      fragment = Nokogiri::HTML5.fragment(rendered_content)

      expect(fragment.at_css("[data-slot=select-value]").text.strip).to eq("Zinc")
      expect(fragment.at_css("[data-value=zinc]")["data-state"]).to eq("checked")
      expect(fragment.at_css("[data-slot=select-trigger]")["data-placeholder"]).to be_nil
    end

    it "hands each option to the theme controller" do
      render_inline(described_class.new)
      item = Nokogiri::HTML5.fragment(rendered_content).at_css("[data-value=stone]")

      expect(item["data-action"]).to include("click->shadcn--theme#setTheme")
      expect(item["data-action"]).to include("click->shadcn--select#select")
    end

    it "can be given the full palette list" do
      render_inline(described_class.new(themes: ShadcnViewComponent::Themes::ALL))
      items = Nokogiri::HTML5.fragment(rendered_content).css("[data-slot=select-item]")

      expect(items.size).to eq(24)
    end
  end
end
