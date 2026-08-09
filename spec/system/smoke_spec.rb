# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the gallery boots" do
  it "loads a preview with the stylesheet and the controllers registered" do
    visit_preview(:button, :variants)
    wait_for_stimulus

    registered = page.evaluate_script(
      "Stimulus.router.modules.map(m => m.definition.identifier).sort()"
    )

    expect(registered).to include("shadcn--dialog", "shadcn--select", "shadcn--theme")
    expect(page).to have_button("Default")

    # The compiled Tailwind is actually applied, not just linked.
    background = page.evaluate_script(
      "getComputedStyle(document.querySelector('[data-slot=button]')).backgroundColor"
    )
    expect(background).not_to eq("rgba(0, 0, 0, 0)")
  end

  # Every family that has a controller, loaded for real. A controller that throws
  # in `connect()` — the `crypto.randomUUID()` bug, say — leaves the component
  # silently dead, and nothing else in the suite would notice.
  #
  # The list is derived rather than typed out, so a new controller is covered the
  # day it lands. `theme` is the one controller with no family of its own; the
  # families that borrow another's are listed below it.
  controllers = Dir[Pathname(__dir__).join("../../app/javascript/shadcn/controllers/*_controller.js")]
                .map { |path| File.basename(path, "_controller.js") }
                .reject { |name| name == "theme" }
                .to_h { |name| [ name, "shadcn--#{name.tr('_', '-')}" ] }
                .merge(
                  "alert_dialog" => "shadcn--dialog",
                  "sheet" => "shadcn--dialog",
                  "mode_toggle" => "shadcn--theme",
                  "mode_switcher" => "shadcn--theme",
                  "theme_selector" => "shadcn--theme"
                )

  it "derives a family list that has not gone empty" do
    expect(controllers.size).to be >= 18
  end

  controllers.each do |family, identifier|
    it "loads #{family} with #{identifier} connected and no JavaScript error" do
      visit_preview(family)
      wait_for_stimulus

      errors = page.driver.browser.logs.get(:browser).reject { |log| log.level == "WARNING" }
      expect(errors.map(&:message)).to be_empty

      # Scoped to the identifier on purpose: the gallery layout carries a
      # ModeToggle and a ThemeSelector, so a bare `[data-controller]` is
      # satisfied by the chrome on every page and proves nothing.
      expect(page).to have_css(%([data-controller~="#{identifier}"]), visible: :all)
    end
  end
end
