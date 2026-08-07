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

    # The example above passes even without an exit animation in flight, because
    # closing set `hidden` in the same tick as `data-state=closed`. Forcing a
    # duration here is what actually puts the layer mid-exit at the moment the
    # link's own pointerdown closes it — `dismiss.js`'s capture-phase listener
    # runs before Turbo's navigation even starts.
    #
    # This checks the cause rather than the eventual, harder-to-pin-down effect:
    # `cacheSnapshot()` clones whatever is in the document once every
    # `turbo:before-cache` listener has run, so what matters is that the wrapper
    # is already gone by then — not what a later restore does with the clone,
    # which this app's own background refetch on a plain link visit overwrites
    # anyway before it can be observed from here. The check itself waits for
    # `turbo:before-render`, which fires only once that dispatch — this queue's
    # own listener included, in whatever order the browser ran it — is done,
    # rather than racing it from inside a same-named listener of its own.
    it "flushes a layer's exit before Turbo caches the page, not after" do
      page.execute_script(<<~JS)
        document.addEventListener("turbo:before-render", () => {
          window.__wrappersAtRender = document.querySelectorAll("[data-radix-popper-content-wrapper]").length
        })
      JS

      within(all("[data-slot=select]").last) do
        force_animations("[data-slot=select-content]", duration: "2s")
        find("[data-slot=select-trigger]").click
      end
      expect(page).to have_css("[data-radix-popper-content-wrapper]", visible: :all)

      # The link click is itself the pointerdown that starts the exit:
      # `dismiss.js` closes the select before Turbo's navigation handling
      # even begins.
      click_link "Go to page two"
      expect(page).to have_css("[data-testid=page-two]")

      expect(page.evaluate_script("window.__wrappersAtRender")).to eq(0)
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
