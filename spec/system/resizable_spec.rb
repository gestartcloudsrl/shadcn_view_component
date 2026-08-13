# frozen_string_literal: true

require "spec_helper"

# Panels are shares of a flex container, so what is asserted here is the two
# numbers the controller moves — and the browser's own layout is what turns them
# into widths.
RSpec.describe "Resizable", :js do
  let(:group) { "[data-slot=resizable-panel-group]" }
  let(:handle) { "[data-slot=resizable-handle]" }

  def shares
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#{group} > [data-slot=resizable-panel]")]
        .map((panel) => Math.round(Number(panel.style.flexGrow)))
    JS
  end

  def drag(by:, vertical: false)
    bar = find(handle, match: :first)
    page.driver.browser.action
        .click_and_hold(bar.native)
        .move_by(vertical ? 0 : by, vertical ? by : 0)
        .release
        .perform
  end

  def press_on_handle(key)
    find(handle, match: :first).send_keys(key)
  end

  describe "the pointer" do
    before do
      visit "/lookbook/preview/shadcn/resizable/with_handle"
      wait_for_stimulus
    end

    it "starts at the sizes the server rendered" do
      expect(shares).to eq([ 25, 75 ])
    end

    # One panel gives exactly what the other takes, which is what keeps a group
    # adding up to what it added up to before.
    it "moves the share from one panel to the other", :aggregate_failures do
      drag(by: 100)

      expect(shares.first).to be > 25
      expect(shares.sum).to eq(100)
    end

    it "stops at the panel's own maximum" do
      drag(by: 400)

      expect(shares).to eq([ 60, 40 ])
    end

    # Far enough to go under the minimum and no further: the handle sits near
    # the left edge of the window, and Selenium refuses a move that would leave
    # the viewport.
    it "stops at the panel's own minimum" do
      drag(by: -120)

      expect(shares).to eq([ 15, 85 ])
    end

    # `data-separator` is upstream's, and it is what a caller styles a handle
    # being dragged with.
    it "says it is being dragged while it is", :aggregate_failures do
      bar = find(handle, match: :first)
      page.driver.browser.action.click_and_hold(bar.native).move_by(40, 0).perform

      expect(bar["data-separator"]).to eq("active")

      page.driver.browser.action.release.perform
      expect(find(handle, match: :first)["data-separator"]).to eq("inactive")
    end

    it "says what the sizes became" do
      page.execute_script(<<~JS)
        window.__sizes = []
        document.addEventListener("shadcn--resizable:resize", (e) => window.__sizes.push(e.detail.sizes.length))
      JS

      drag(by: 60)

      expect(page.evaluate_script("window.__sizes").last).to eq(2)
    end
  end

  # The separator pattern: the arrows along the group's axis move it, the ones
  # across it do nothing, and Home and End push it all the way. Five points a
  # press, which is `react-resizable-panels`' own step.
  describe "the keyboard" do
    before do
      visit "/lookbook/preview/shadcn/resizable/with_handle"
      wait_for_stimulus
    end

    it "moves five points at a time", :aggregate_failures do
      press_on_handle(:right)
      expect(shares).to eq([ 30, 70 ])

      press_on_handle(:left)
      expect(shares).to eq([ 25, 75 ])
    end

    it "ignores the arrows across the group's own axis" do
      press_on_handle(:down)

      expect(shares).to eq([ 25, 75 ])
    end

    it "pushes all the way to the limits", :aggregate_failures do
      press_on_handle(:end)
      expect(shares).to eq([ 60, 40 ])

      press_on_handle(:home)
      expect(shares).to eq([ 15, 85 ])
    end

    # A separator is a control, and this is the half that makes it one: without
    # the value a screen reader has a divider it cannot read.
    it "publishes where it sits", :aggregate_failures do
      bar = find(handle, match: :first)

      expect(bar["aria-valuenow"]).to eq("25")
      expect(bar["aria-valuemin"]).to eq("15")
      expect(bar["aria-valuemax"]).to eq("60")
      expect(bar["aria-controls"]).to eq(all("#{group} > [data-slot=resizable-panel]").first["id"])

      press_on_handle(:right)
      expect(find(handle, match: :first)["aria-valuenow"]).to eq("30")
    end
  end

  describe "a vertical group" do
    before do
      visit "/lookbook/preview/shadcn/resizable/vertical"
      wait_for_stimulus
    end

    # The separator's orientation is the opposite of the group's, because a
    # column of panels is divided by a horizontal line — and `role="separator"`
    # is horizontal unless it says otherwise, so it always says.
    #
    # The group itself carries no `aria-orientation`: no role it could take
    # supports one, axe refuses it, and upstream's own DOM has none either. What
    # says which way a group runs is the direction it lays its panels out in,
    # so that is what is asserted.
    it "lays the separator across the panels", :aggregate_failures do
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{group}')).flexDirection"))
        .to eq("column")
      expect(find(handle, match: :first)["aria-orientation"]).to eq("horizontal")
      expect(find(group)["aria-orientation"]).to be_nil
    end

    it "moves with the arrows that lie along it", :aggregate_failures do
      press_on_handle(:down)
      expect(shares).to eq([ 30, 70 ])

      press_on_handle(:right)
      expect(shares).to eq([ 30, 70 ])
    end

    it "drags along its own axis" do
      drag(by: 60, vertical: true)

      expect(shares.first).to be > 25
    end
  end
end
