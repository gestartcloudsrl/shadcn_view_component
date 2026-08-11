# frozen_string_literal: true

require "spec_helper"

# Opening, closing, Escape, the focus trap and the scroll lock are the dialog's
# and run on `shadcn--dialog`; `spec/system/dialog_spec.rb` covers them. What is
# this component's own is the drag, and a drag is a path with timing rather than
# a click, so it is driven through CDP — `execute_script` would dispatch the
# handler directly and prove nothing about whether a hand could do it. See
# decisions/03-testing.md, "When Selenium's pointer will not land, use CDP".
RSpec.describe "Drawer", :js do
  let(:content) { "[data-slot=drawer-content]" }
  let(:overlay) { "[data-slot=drawer-overlay]" }

  def cdp(method, **params) = page.driver.browser.execute_cdp(method, **params)

  # Touch rather than mouse, and not only because a drawer is a phone component.
  # A touch pointer is *implicitly captured* by whatever it started on, so the
  # moves keep arriving after the panel has moved out from under the finger — a
  # mouse is not, and vaul binds its handlers to the panel, so a retracting drag
  # would stop being delivered halfway. Driving this with a mouse would test a
  # gesture nobody performs and miss the one everybody does.
  def touch(type, point)
    points = type == "touchEnd" ? [] : [ { x: point[0], y: point[1] } ]

    cdp("Input.dispatchTouchEvent", type:, touchPoints: points)
  end

  # `steps` and `pause` together are the speed, which is the whole point: the
  # same distance at two paces has to come out as two different outcomes.
  def drag(from:, by:, steps: 6, pause: 0.05)
    touch("touchStart", from)
    steps.times do |i|
      t = (i + 1).to_f / steps
      touch("touchMove", [ (from[0] + by[0] * t).round, (from[1] + by[1] * t).round ])
      sleep pause
    end
    touch("touchEnd", nil)
  end

  # The handle, which is the part of the panel nothing else claims — pressing on
  # the header or a button would test those as well as the drag.
  def grip
    box = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector(#{content.to_json}).getBoundingClientRect()
        return [Math.round(r.left + r.width / 2), Math.round(r.top + 12)]
      })()
    JS
    box.map(&:to_i)
  end

  def translated
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{content.to_json})
        return new DOMMatrixReadOnly(getComputedStyle(el).transform).m42
      })()
    JS
  end

  def open_drawer(example = :default)
    visit_preview(:drawer, example)
    wait_for_stimulus
    first("[data-slot=drawer-trigger]").click
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    # vaul refuses to drag for 500ms after opening, so every drag below would
    # otherwise be measuring that refusal rather than the thing under test.
    sleep 0.6
  end

  it "opens from its trigger, bottom-anchored, with the handle showing" do
    open_drawer

    expect(find(content)["data-vaul-drawer-direction"]).to eq("bottom")
    expect(find(content)["role"]).to eq("dialog")
    expect(page).to have_css("#{overlay}[data-state=open]", visible: :visible)
  end

  describe "the drag" do
    before { open_drawer }

    # Slow and short: below both thresholds, so it has to spring back rather
    # than close. Without this the two closing examples below would be satisfied
    # by a drawer that closes on any drag at all.
    it "comes back when the drag is short and slow" do
      x, y = grip
      drag(from: [ x, y ], by: [ 0, 60 ], steps: 6, pause: 0.06)

      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
      expect(translated).to be_within(1).of(0)
    end

    # Far enough — past a quarter of the panel — at the same slow pace, so it is
    # the distance closing it and not the speed.
    it "closes when dragged far, however slowly" do
      x, y = grip
      height = page.evaluate_script("document.querySelector(#{content.to_json}).getBoundingClientRect().height")
      drag(from: [ x, y ], by: [ 0, (height * 0.45).round ], steps: 8, pause: 0.06)

      expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
    end

    # The other half of vaul's release: thrown fast, a short drag closes it too.
    # The distance here is the same 60px that sprang back above, so only the
    # speed can be the difference.
    it "closes when thrown, however short" do
      x, y = grip
      drag(from: [ x, y ], by: [ 0, 60 ], steps: 4, pause: 0.001)

      expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
    end

    # Dragging into the drawer has nowhere to go, so vaul rubber-bands it rather
    # than stopping it dead — logarithmically, so 100px of pointer gives back
    # about 20px of panel.
    #
    # It has to be reached by dragging *down* first: `shouldDrag` refuses an
    # upward gesture outright, handing it to whatever scrolls, so the damping is
    # only ever reached by a drag that was already allowed and has come back
    # past where it started. Pressing and pulling straight up moves nothing at
    # all, and an example written that way passes with the damping deleted.
    it "gives a little and no more when pulled back past the start" do
      x, y = grip
      touch("touchStart", [ x, y ])
      touch("touchMove", [ x, y + 40 ])
      sleep 0.05
      touch("touchMove", [ x, y - 100 ])
      sleep 0.05
      moved = translated
      touch("touchEnd", nil)

      expect(moved).to be_between(-40, -5)
      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    end

    # Throwing it away and opening it again, which is the ordinary way to use
    # one twice and the only path on which the inline styles the drag writes are
    # still there afterwards. They belong to a gesture that is over: left
    # behind, the panel comes back up already pushed half off its own edge.
    it "comes back square after being thrown away and reopened" do
      x, y = grip
      drag(from: [ x, y ], by: [ 0, 60 ], steps: 4, pause: 0.001)
      expect(page).to have_css("#{content}[data-state=closed]", visible: :all)

      first("[data-slot=drawer-trigger]").click
      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
      sleep 0.6

      expect(translated).to be_within(1).of(0)
      expect(page.evaluate_script(<<~JS)).to eq("")
        document.querySelector(#{content.to_json}).style.transition
      JS
    end

    # The overlay thins out as the panel leaves, which is the only part of the
    # drag a person sees away from the panel itself.
    it "fades the overlay in step with the panel" do
      x, y = grip
      touch("touchStart", [ x, y ])
      touch("touchMove", [ x, y + 80 ])
      sleep 0.05
      opacity = page.evaluate_script("getComputedStyle(document.querySelector(#{overlay.to_json})).opacity").to_f
      touch("touchEnd", nil)

      expect(opacity).to be < 0.95
      expect(opacity).to be > 0.3
    end
  end

  # The reason `shouldDrag` exists. A drawer with a list in it has two things a
  # downward pull could mean, and getting this wrong makes the component unusable
  # rather than merely wrong: every attempt to read the list throws it away.
  describe "with a scrollable body" do
    let(:list) { "[data-slot=drawer-content] .overflow-y-auto" }

    before { open_drawer(:scrollable) }

    # Asserting the outcome, and honest about who produces it: measured here,
    # Chrome scrolls the list itself and fires `pointercancel` after the first
    # move, so the gesture never reaches the branch in `shouldDrag` that would
    # have decided the same thing, and this example passes with that branch
    # deleted. It is kept for the outcome — a person pulling on the list must
    # get the list — not as evidence about the code.
    #
    # Nothing here can be: Chrome cancels a pointer stream that starts inside a
    # scroll container whichever way it then travels, so neither the climb nor
    # the direction short-circuit above it is reachable from a spec. Both stay,
    # because they are vaul's and they answer on a platform that does not step
    # in first. Recorded under "What is still unverified" in
    # decisions/03-testing.md.
    it "leaves the drawer alone while the list is being scrolled" do
      page.execute_script("document.querySelector(#{list.to_json}).scrollTop = 120")
      box = page.evaluate_script(<<~JS)
        (() => {
          const r = document.querySelector(#{list.to_json}).getBoundingClientRect()
          return [Math.round(r.left + r.width / 2), Math.round(r.top + r.height / 2)]
        })()
      JS

      drag(from: box.map(&:to_i), by: [ 0, 120 ], steps: 6, pause: 0.03)

      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
      expect(translated).to be_within(1).of(0)
      expect(page.evaluate_script("document.querySelector(#{list.to_json}).scrollTop")).to be < 120
    end

    # And the drawer is still draggable from the part of it that is not the list
    # — otherwise the fix for the above would just be "never drag".
    it "still drags from the handle" do
      x, y = grip
      height = page.evaluate_script("document.querySelector(#{content.to_json}).getBoundingClientRect().height")
      drag(from: [ x, y ], by: [ 0, (height * 0.45).round ], steps: 8, pause: 0.05)

      expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
    end
  end

  # A sideways drawer has no scroll axis competing with it, so it drags from
  # anywhere — and it closes towards its own edge, not downwards.
  it "drags a right-hand drawer sideways" do
    visit_preview(:drawer, :sides)
    wait_for_stimulus
    all("[data-slot=drawer-trigger]").last.click
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    sleep 0.6

    box = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector("#{content}[data-state=open]").getBoundingClientRect()
        return [Math.round(r.left + 20), Math.round(r.top + r.height / 2)]
      })()
    JS

    drag(from: box.map(&:to_i), by: [ 200, 0 ], steps: 6, pause: 0.03)

    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
  end
end
