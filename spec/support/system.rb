# frozen_string_literal: true

require "capybara/rspec"
require "selenium-webdriver"

# The system specs drive the real thing: the dummy app, the compiled Tailwind
# bundle and the Stimulus controllers, in a real browser. They are the only
# place the JavaScript is executed — `stimulus_contract_spec.rb` only checks
# that the names on both sides line up.
Capybara.register_driver :shadcn_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[
    --headless=new
    --no-sandbox
    --disable-gpu
    --disable-dev-shm-usage
    --window-size=1400,1000
  ].each { |argument| options.add_argument(argument) }

  # Escape and arrow keys must reach the page, and animations only get in the
  # way of asserting on state.
  options.add_argument("--force-prefers-reduced-motion")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
end

# How long Capybara waits for a page to catch up before failing. Five is right
# on a machine that is not busy; a loaded one — or a CI runner sharing a core —
# needs more, and raising it there is better than a suite that fails on the
# machine rather than on the code. `CAPYBARA_WAIT=15 bundle exec rspec` when a
# run is fighting for the CPU.
Capybara.default_max_wait_time = Float(ENV.fetch("CAPYBARA_WAIT", 5))
Capybara.disable_animation = true

module SystemHelpers
  # The component gallery is where every component already has a realistic
  # example, so the system specs drive those rather than inventing markup that
  # would drift from what ships. One helper, so Lookbook's URL scheme is
  # referenced in exactly one place.
  def visit_preview(family, example = :default)
    visit "/lookbook/preview/shadcn/#{family}/#{example}"
    expect(page).to have_css("[data-controller]", visible: :all, wait: 5)
  end

  # Stimulus connects after the module graph loads; wait for it rather than
  # sleeping.
  def wait_for_stimulus
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("!!window.Stimulus")
    end
  end

  def state_of(selector)
    page.find(selector, visible: :all)["data-state"]
  end

  # The driver runs with `--force-prefers-reduced-motion`, and
  # `Capybara.disable_animation` injects `* { animation-duration: 0s !important }`
  # into every page it serves. Both are right for the rest of the suite —
  # elsewhere an animation is only something to wait out — and both make an exit
  # animation impossible to observe.
  #
  # Rather than run this file under a second driver, give the elements under test
  # a duration that outlives an assertion. Only the duration is forced:
  # `animation-name` still comes from the component's own
  # `data-[state=closed]:animate-out`, so what the assertions read is the shipped
  # class and not the harness.
  #
  # An injected `<style>` beats Capybara's own rule — `!important` at
  # specificity zero — but not the accordion utilities' `!important`, which
  # lives inside Tailwind's `@layer utilities`. Cascade layers invert the usual
  # rule for `!important`: a *layered* `!important` beats an unlayered one at
  # any specificity, so the injected stylesheet could not touch it — see
  # [the cascade-layer trap](../../.claude/docs/decisions/02-javascript.md#the-one-css-trap-worth-remembering).
  # Setting the property inline is the only thing that outranks a layered
  # `!important` short of another layer, so that is what this does instead.
  #
  # The elements are resolved through Capybara rather than
  # `document.querySelectorAll`, so `within(…)` scopes this the way it scopes
  # every other lookup beside it. The gallery layout carries a ThemeSelector and
  # a ModeToggle of its own, so a bare `[data-slot=select-content]` is never
  # only the preview's, and a caller that wrote `within` to say which one it
  # meant was silently getting both.
  #
  # Inline styles only reach elements that exist when this runs, unlike the
  # stylesheet rule it replaces, which would have matched anything appearing
  # later too. `minimum: 1` at least makes a selector that matches nothing yet
  # wait, and then fail by name instead of passing silently.
  def force_animations(selector, duration: "400ms")
    page.all(selector, visible: :all, minimum: 1).each do |element|
      page.execute_script(<<~JS, element, duration)
        arguments[0].style.setProperty("animation-duration", arguments[1], "important")
      JS
    end
  end

  # The names of the CSS animations the browser has scheduled on an element.
  # `animate-in` sets `animation-name: enter`, `animate-out` sets `exit`.
  #
  # This is what makes an animation spec deterministic: it reads what the browser
  # decided to run, rather than trying to catch a frame while it runs.
  def animations_on(selector)
    page.evaluate_script(
      "document.querySelector('#{selector}').getAnimations().map((a) => a.animationName)"
    )
  end

  # Clicking an overlay by its element does not work: Selenium aims at the
  # centre, which is exactly where the dialog sits. Aim at a viewport corner
  # instead, which is what "outside" means to the dismiss layer.
  def click_outside(x: 8, y: 8)
    page.driver.browser.action.move_to_location(x, y).click.perform
  end

  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end

  # Turbo paints the cached snapshot first and swaps in the fresh body after.
  # Asserting during that preview is a race — it is the *old* DOM — so wait for
  # the marker Turbo puts on <html> while a preview is showing.
  def wait_for_turbo
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 while page.evaluate_script("document.documentElement.hasAttribute('data-turbo-preview')")
    end
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :shadcn_headless_chrome

    # Pin the colour scheme, because otherwise the *machine* picks it. Headless
    # Chrome follows the desktop it runs on: on a developer's Mac in dark mode
    # it reports `dark`, on a Linux CI runner with no preference it reports
    # `light`. So the accessibility suite spent this project's whole life
    # auditing whichever palette the author happened to be sitting in front of —
    # and the first run on CI found eleven contrast violations in the other one,
    # every one of them real.
    #
    # Light, because it is what a host gets with no cookie and no preference,
    # and because the spec that audits the dark class does so by adding it: it
    # was adding `.dark` to a page that was already dark, checking one mode
    # twice.
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-color-scheme", value: "light" } ]
    )
  end
end
