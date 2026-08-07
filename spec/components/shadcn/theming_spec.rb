# frozen_string_literal: true

require "spec_helper"

RSpec.describe "theming" do
  describe ShadcnViewComponent::Themes do
    it "carries every palette shadcn ships", :aggregate_failures do
      expect(described_class::ALL.size).to eq(24)
      expect(described_class.names).to include("neutral", "zinc", "mauve", "blue", "rose")
    end

    it "separates the base greys from the accent palettes", :aggregate_failures do
      expect(described_class::BASE_COLORS.map { |theme| theme[:name] })
        .to eq(%w[neutral stone zinc mauve olive mist taupe])
      expect(described_class::ACCENTS).not_to be_empty
      expect(described_class::BASE_COLORS + described_class::ACCENTS)
        .to match_array(described_class::ALL)
    end

    it "gives the base colours a complete token set for both modes", :aggregate_failures do
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
    it "gives the accents a partial overlay built around primary", :aggregate_failures do
      described_class::ACCENTS.each do |theme|
        expect(theme[:light]).to include("primary", "primary-foreground"),
                                 "#{theme[:name]} does not set a primary"
        expect(theme[:light].keys).not_to include("background"),
                                          "#{theme[:name]} unexpectedly redefines background"
      end
    end

    describe ".find" do
      it "looks a palette up by name" do
        expect(described_class.find("zinc")[:title]).to eq("Zinc")
      end
    end

    # Flat rather than a context each: the outer "theming" group already costs a
    # nesting level, and two one-line examples do not need the ceremony.
    describe ".exists?" do
      it "is true for a palette it ships" do
        expect(described_class.exists?("zinc")).to be(true)
      end

      it "is false for one it does not" do
        expect(described_class.exists?("nope")).to be(false)
      end
    end
  end

  describe "the generated stylesheet" do
    subject(:css) do
      Pathname(__dir__).join("../../../app/assets/stylesheets/shadcn-themes.css").read
    end

    it "defines a class and a data-attribute selector for every palette", :aggregate_failures do
      ShadcnViewComponent::Themes.names.each do |name|
        expect(css).to include(".theme-#{name},\n[data-shadcn-theme=\"#{name}\"] {"),
                       "#{name} has no light selector"
        expect(css).to include(".dark .theme-#{name},\n.dark[data-shadcn-theme=\"#{name}\"] {"),
                       "#{name} has no dark selector"
      end
    end

    it "matches the vendored registry values", :aggregate_failures do
      zinc = ShadcnViewComponent::Themes.find("zinc")

      expect(css).to include("--primary: #{zinc[:light]['primary']};")
      expect(css).to include("--primary: #{zinc[:dark]['primary']};")
    end
  end

  describe Shadcn::ModeToggle::Component do
    before { render_inline(described_class.new) }

    it "wraps the control in the theme controller", :aggregate_failures do
      expect(root["data-controller"]).to eq("shadcn--theme")
      expect(root["data-slot"]).to eq("mode-toggle")
    end

    it "offers light, dark and system" do
      expect(slots("dropdown-menu-item").map { |item| item["data-mode"] })
        .to eq(%w[light dark system])
    end

    it "keeps the dropdown's own actions alongside the theme one", :aggregate_failures do
      actions = fragment.at_css("[data-mode=dark]")["data-action"]

      expect(actions).to include("click->shadcn--theme#setMode")
      expect(actions).to include("click->shadcn--dropdown-menu#select")
      # The dropdown's action must appear once, not once per merge.
      expect(actions.scan("shadcn--dropdown-menu#select").size).to eq(1)
    end

    it "renders the sun and moon that cross-fade on .dark", :aggregate_failures do
      expect(fragment.css("svg").map { |svg| svg["class"] }.join)
        .to include("lucide-sun", "lucide-moon")
      expect(root.text).to include("Toggle theme")
    end

    # The upstream example is vendored alongside the components it uses, so the
    # icon classes stay pinned to it the way the registry components are.
    it "uses the icon classes from mode-toggle.tsx", :aggregate_failures do
      tsx = Pathname(__dir__).join("../../../vendor/shadcn/examples/mode-toggle.tsx").read

      expect(tsx).to include(described_class::SUN_CLASSES)
      expect(tsx).to include(described_class::MOON_CLASSES)
    end
  end

  describe Shadcn::ModeSwitcher::Component do
    before { render_inline(described_class.new) }

    it "wraps the control in the theme controller" do
      expect(root["data-controller"]).to eq("shadcn--theme")
    end

    it "renders a single icon button bound to the toggle action", :aggregate_failures do
      expect(slots("button").size).to eq(1)
      expect(slot("button")["data-action"]).to include("shadcn--theme#toggle")
      expect(slot("button")["data-size"]).to eq("icon")
    end
  end

  describe Shadcn::ThemeSelector::Component do
    context "without arguments" do
      before { render_inline(described_class.new) }

      it "lists the base colours" do
        expect(slots("select-item").map { |item| item["data-value"] })
          .to eq(ShadcnViewComponent::Themes::BASE_COLORS.map { |theme| theme[:name] })
      end

      it "hands each option to the theme controller", :aggregate_failures do
        actions = fragment.at_css("[data-value=stone]")["data-action"]

        expect(actions).to include("click->shadcn--theme#setTheme")
        expect(actions).to include("click->shadcn--select#select")
      end

      # A `role="combobox"` may not take its name from its content, so the name
      # has to come from the label — the same way the FormBuilder names its
      # selects, with `aria-labelledby` rather than `<label for>`.
      it "names the trigger with aria-labelledby pointing at the label" do
        expect(slot("select-trigger")["aria-labelledby"]).to eq(slot("label")["id"])
      end
    end

    context "with a value" do
      before { render_inline(described_class.new(value: "zinc")) }

      it "shows that palette's title on the trigger" do
        expect(slot("select-value").text.strip).to eq("Zinc")
      end

      it "marks that palette checked" do
        expect(fragment.at_css("[data-value=zinc]")["data-state"]).to eq("checked")
      end

      it "stops treating the trigger as a placeholder" do
        expect(slot("select-trigger")["data-placeholder"]).to be_nil
      end
    end

    context "with the full palette list" do
      before { render_inline(described_class.new(themes: ShadcnViewComponent::Themes::ALL)) }

      it "lists every palette" do
        expect(slots("select-item").size).to eq(24)
      end
    end
  end
end
