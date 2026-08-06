# frozen_string_literal: true

require "spec_helper"

# A Rails 8 component library lives on pages served by Turbo, so the controllers
# have to survive Turbo Drive's page caching and morph refreshes. The dummy app
# loads Turbo for exactly this reason.
RSpec.describe "Under Turbo", :js do
  before do
    visit "/turbo-probe/one"
    wait_for_stimulus
    expect(page).to have_css("[data-testid=page-one]")
  end

  it "is actually running Turbo" do
    expect(page.evaluate_script("!!window.Turbo")).to be(true)
  end

  describe "Drive navigation" do
    it "keeps the components working on the page it navigates to" do
      click_link "Go to page two"
      expect(page).to have_css("[data-testid=page-two]")
      wait_for_turbo

      find("[data-slot=checkbox]").click
      expect(find("[data-slot=checkbox]")["data-state"]).to eq("checked")
    end

    it "releases the scroll lock when navigating away from an open dialog" do
      click_button "Open dialog"
      expect(page.evaluate_script("document.body.style.overflow")).to eq("hidden")

      # The overlay covers the page, as a modal should, so the link cannot be
      # clicked — navigate the way a redirect or a Turbo Stream would.
      page.execute_script("window.Turbo.visit('/turbo-probe/two')")
      expect(page).to have_css("[data-testid=page-two]")
      wait_for_turbo

      expect(page.evaluate_script("document.body.style.overflow")).to eq("")
    end

    # A floating layer builds its positioned wrapper at runtime. Leaving the page
    # with one open must not leave the wrapper behind in the cached snapshot, or
    # the content comes back orphaned outside any controller.
    it "leaves no orphaned wrapper behind when navigating with a layer open" do
      # The layout header carries a ThemeSelector, which is also a Select.
      within(all("[data-slot=select]").last) { find("[data-slot=select-trigger]").click }
      expect(page).to have_css("[data-radix-popper-content-wrapper]", visible: :all)

      click_link "Go to page two"
      expect(page).to have_css("[data-testid=page-two]")
      wait_for_turbo
      click_link "Back to page one"
      expect(page).to have_css("[data-testid=page-one]")
      wait_for_turbo

      expect(page).to have_no_css("[data-radix-popper-content-wrapper]", visible: :all)
      within(all("[data-slot=select]").last) do
        expect(find("[data-slot=select-content]", visible: :all)["data-state"]).to eq("closed")
      end
    end

    it "restores a working page from the Turbo cache" do
      click_link "Go to page two"
      expect(page).to have_css("[data-testid=page-two]")
      wait_for_turbo
      click_link "Back to page one"
      expect(page).to have_css("[data-testid=page-one]")
      wait_for_turbo

      click_button "Open dialog"
      expect(page).to have_css("[data-slot=dialog-content]")
      press(:escape)
      expect(page).to have_no_css("[data-slot=dialog-content]")
    end
  end

  describe "morph refresh" do
    def morph
      page.execute_script("window.Turbo.visit(window.location.href, { action: 'replace' })")
      # The morph rewrites attributes in place, so wait on the effect rather than
      # on a navigation that never repaints the whole page.
      sleep 0.6
    end

    # Idiomorph rewrites attributes without disconnecting the controllers, so
    # `connect()` never runs again. Without a resync the DOM goes back to the
    # server's state while the controller still holds the old ids and targets.
    it "leaves the DOM and the controller in agreement" do
      find("[data-slot=accordion-trigger]").click
      expect(find("[data-slot=accordion-content]", visible: :all)["data-state"]).to eq("open")

      morph

      trigger = find("[data-slot=accordion-trigger]")
      panel = find("[data-slot=accordion-content]", visible: :all)

      expect(panel["data-state"]).to eq("closed")
      expect(trigger["aria-expanded"]).to eq("false")
      expect(trigger["id"]).to match(/\Ashadcn-accordion-trigger-\d+\z/)
      expect(trigger["aria-controls"]).to eq(panel["id"])
    end

    it "still responds to interaction afterwards" do
      find("[data-slot=accordion-trigger]").click
      morph

      find("[data-slot=accordion-trigger]").click

      expect(find("[data-slot=accordion-content]")["data-state"]).to eq("open")
      expect(find("[data-slot=accordion-trigger]")["aria-expanded"]).to eq("true")
    end

    it "does not leave a dialog half-open" do
      click_button "Open dialog"
      expect(page).to have_css("[data-slot=dialog-content]")

      morph

      content = find("[data-slot=dialog-content]", visible: :all)
      trigger = find("[data-slot=dialog-trigger]")

      expect(content["data-state"]).to eq(trigger["aria-expanded"] == "true" ? "open" : "closed")
    end
  end
end
