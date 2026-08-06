# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Theming", :js do
  def stored(key) = page.evaluate_script("localStorage.getItem('#{key}')")
  def html_class = page.evaluate_script("document.documentElement.className")
  def body_theme = page.evaluate_script("[...document.body.classList].find(c => c.startsWith('theme-'))")
  def token(name) = page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--#{name}').trim()")

  def choose_mode(mode)
    within(first("[data-slot=mode-toggle]")) { find("[data-slot=dropdown-menu-trigger]").click }
    find("[data-slot=dropdown-menu-item][data-mode=#{mode}]").click
  end

  before do
    visit_preview(:mode_toggle)
    page.execute_script("localStorage.clear()")
    visit_preview(:mode_toggle)
    wait_for_stimulus
  end

  describe "mode" do
    it "follows the system preference when nothing is stored" do
      expect(stored("shadcn-ui-mode")).to be_nil

      system_dark = page.evaluate_script("matchMedia('(prefers-color-scheme: dark)').matches")
      expect(html_class.include?("dark")).to eq(system_dark)
    end

    it "switches to dark and back to light" do
      choose_mode(:dark)
      expect(html_class).to include("dark")
      expect(page.evaluate_script("document.documentElement.style.colorScheme")).to eq("dark")
      expect(stored("shadcn-ui-mode")).to eq("dark")

      choose_mode(:light)
      expect(html_class).not_to include("dark")
      expect(page.evaluate_script("document.documentElement.style.colorScheme")).to eq("light")
    end

    it "repoints the tokens, which is what the components read" do
      choose_mode(:light)
      light = token("background")

      choose_mode(:dark)
      expect(token("background")).not_to eq(light)
    end

    it "marks the chosen mode in the menu" do
      choose_mode(:dark)
      within(first("[data-slot=mode-toggle]")) { find("[data-slot=dropdown-menu-trigger]").click }

      active = all("[data-slot=dropdown-menu-item][data-mode]").to_h { |i| [ i["data-mode"], i["data-active"] ] }
      expect(active).to eq("light" => "false", "dark" => "true", "system" => "false")
    end

    # The whole point of the inline script: the preference is applied before the
    # first paint, not after the module graph loads.
    it "survives a reload with no flash of the wrong mode" do
      choose_mode(:dark)
      visit_preview(:card)

      expect(html_class).to include("dark")
      expect(page.evaluate_script("document.documentElement.dataset.shadcnTheme")).not_to be_nil
    end

    it "mirrors the mode into a cookie so the server can render it" do
      choose_mode(:dark)

      expect(page.driver.browser.manage.cookie_named("shadcn-ui-mode")[:value]).to eq("dark")
    end
  end

  describe "palette" do
    def choose_theme(name)
      within("[data-slot=theme-selector]", match: :first) do
        find("[data-slot=select-trigger]").click
      end
      find("[data-slot=select-item][data-value=#{name}]").click
    end

    it "swaps the theme class on the body" do
      expect(body_theme).to eq("theme-neutral")

      choose_theme(:mauve)
      expect(body_theme).to eq("theme-mauve")
      expect(stored("shadcn-ui-theme")).to eq("mauve")
    end

    it "changes the tokens the components resolve against" do
      choose_mode(:light)
      neutral = token("primary")

      choose_theme(:mauve)
      expect(token("primary")).not_to eq(neutral)
    end

    it "is rendered server-side on the next request, from the cookie" do
      choose_theme(:stone)
      visit_preview(:card)

      # Present in the markup before any JavaScript could have run.
      expect(page).to have_css("body.theme-stone")
      expect(body_theme).to eq("theme-stone")
    end

    it "keeps the mode and the palette independent" do
      choose_mode(:dark)
      choose_theme(:zinc)

      expect(html_class).to include("dark")
      expect(body_theme).to eq("theme-zinc")
    end
  end

  describe "the switcher button" do
    it "flips straight between light and dark" do
      visit_preview(:mode_switcher)
      wait_for_stimulus

      before = html_class.include?("dark")
      first("[data-slot=mode-switcher]").find("[data-slot=button]").click

      expect(html_class.include?("dark")).to eq(!before)
    end
  end
end
