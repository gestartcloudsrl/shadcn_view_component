# frozen_string_literal: true

require "spec_helper"

# What is worth asserting here is the small part that is not the dropdown menu.
# Eleven of this family's fifteen slots are the dropdown's restamped, and one
# controller drives both — `spec/system/dropdown_menu_spec.rb` covers the
# keyboard, the submenus and the checkbox items, and repeating that here would
# assert the same code twice under a different name.
#
# What is this component's own: the way in, and where the panel lands.
RSpec.describe "Context menu", :js do
  let(:trigger) { "[data-slot=context-menu-trigger]" }
  let(:content) { "[data-slot=context-menu-content]" }

  # `contextmenu` rather than a right-click through the driver: Selenium's
  # context-click opens the *browser's* menu on some platforms, and what is
  # under test is the page's response to the event.
  def right_click_at(offset_x, offset_y)
    page.execute_script(<<~JS)
      const area = document.querySelector(#{trigger.to_json})
      const rect = area.getBoundingClientRect()
      area.dispatchEvent(new MouseEvent("contextmenu", {
        bubbles: true, cancelable: true,
        clientX: Math.round(rect.left + #{offset_x}),
        clientY: Math.round(rect.top + #{offset_y})
      }))
    JS
  end

  def content_box
    page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector(#{content.to_json}).getBoundingClientRect()
        return { left: Math.round(rect.left), top: Math.round(rect.top) }
      })()
    JS
  end

  before do
    visit_preview(:context_menu)
    wait_for_stimulus
  end

  it "stays closed until the area is right-clicked" do
    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)

    right_click_at(20, 20)

    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
  end

  # The whole of what makes this a context menu rather than a dropdown: the
  # panel is measured against the point, not against the element. Pressing two
  # places in the same area has to put it in two places.
  it "opens where the pointer was, not where the area is" do
    right_click_at(20, 20)
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    near = content_box

    right_click_at(200, 100)
    far = content_box

    expect(far["left"] - near["left"]).to be_within(6).of(180)
    expect(far["top"] - near["top"]).to be_within(6).of(80)
  end

  # The browser's own menu must not appear over ours, which means the event has
  # to be cancelled rather than merely listened to.
  it "cancels the browser's menu" do
    cancelled = page.evaluate_script(<<~JS)
      (() => {
        const area = document.querySelector(#{trigger.to_json})
        const event = new MouseEvent("contextmenu", {
          bubbles: true, cancelable: true, clientX: 10, clientY: 10
        })
        area.dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS

    expect(cancelled).to be(true)
  end

  it "closes on Escape" do
    right_click_at(20, 20)
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    page.execute_script("document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))")

    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
  end

  # The trigger is a region, not a control: no classes upstream and no
  # `aria-haspopup`, because there is no keyboard route to a context menu and
  # claiming one would promise something that does not exist.
  #
  # And a `<span>`, which is Radix's own — a `<div>` would be block where this is
  # inline, and the same markup would lay out differently. Read from the live
  # demo, not from the shadcn file, which delegates and shows nothing.
  it "leaves the trigger a plain inline region" do
    area = find(trigger)

    expect(area.tag_name).to eq("span")
    expect(area["aria-haspopup"]).to be_nil
    expect(area["role"]).to be_nil
  end

  # Radix hands the gesture back to the browser when the region is disabled
  # (context-menu.tsx:158-161): a region that does nothing should not also take
  # away the menu you expected.
  it "lets the browser's menu through when the region is disabled" do
    page.execute_script(<<~JS)
      document.querySelector(#{trigger.to_json}).removeAttribute("data-action")
    JS

    cancelled = page.evaluate_script(<<~JS)
      (() => {
        const area = document.querySelector(#{trigger.to_json})
        const event = new MouseEvent("contextmenu", {
          bubbles: true, cancelable: true, clientX: 10, clientY: 10
        })
        area.dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS

    expect(cancelled).to be(false)
    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
  end

  # A submenu opened by hovering has to be closable by not hovering. Before
  # this, nothing shut one: it opened on `pointerenter` and then waited for
  # Escape or a click outside, so moving the mouse anywhere else left it hanging
  # over the menu. Reported from this component, though the code is the
  # dropdown's — and asserted here because this is the preview with a submenu
  # in it.
  #
  # Radix grants the same grace but shapes it: a polygon from the exit point to
  # the panel's edges, honoured only while the pointer is moving toward it
  # (menu.tsx:1136-1160). This is the time half without the direction half.
  # Crossing a sub-trigger on the way somewhere else must not open its panel:
  # Radix waits 100ms first (menu.tsx:1123). Read at a moment rather than
  # waited for — `have_css` retries for two seconds and would be satisfied by a
  # panel that opened late, or instantly, or not at all.
  it "does not open a submenu for a pointer that crosses it" do
    right_click_at(20, 20)
    trigger_selector = "[data-slot=context-menu-sub-trigger]"
    expect(page).to have_css(trigger_selector, visible: :visible)

    page.execute_script(<<~JS)
      const el = document.querySelector(#{trigger_selector.to_json})
      el.dispatchEvent(new PointerEvent("pointerenter", { pointerType: "mouse" }))
      el.dispatchEvent(new PointerEvent("pointerleave", { pointerType: "mouse" }))
    JS
    sleep 0.05

    expect(find("[data-slot=context-menu-sub-content]", visible: :all)["data-state"]).to eq("closed")
  end

  describe "a submenu" do
    let(:sub_trigger) { "[data-slot=context-menu-sub-trigger]" }
    let(:sub_content) { "[data-slot=context-menu-sub-content]" }

    def point(selector, event)
      page.execute_script(<<~JS)
        document.querySelector(#{selector.to_json}).dispatchEvent(
          new PointerEvent(#{event.to_json}, { bubbles: false, pointerType: "mouse" })
        )
      JS
    end

    before do
      right_click_at(20, 20)
      expect(page).to have_css(sub_trigger, visible: :visible)
      point(sub_trigger, "pointerenter")
      expect(page).to have_css("#{sub_content}[data-state=open]", visible: :visible)
    end

    it "closes once the pointer has left the trigger" do
      point(sub_trigger, "pointerleave")

      expect(page).to have_css("#{sub_content}[data-state=closed]", visible: :all)
    end

    # The half the grace exists for: the panel is a sibling of the trigger, so
    # reaching it means leaving the trigger, and a close that could not be
    # cancelled would put the submenu out of reach.
    it "stays open when the pointer crosses from the trigger onto the panel" do
      point(sub_trigger, "pointerleave")
      point(sub_content, "pointerenter")

      sleep 0.6
      expect(page).to have_css("#{sub_content}[data-state=open]", visible: :visible)
    end

    it "closes again when the pointer leaves the panel" do
      point(sub_trigger, "pointerleave")
      point(sub_content, "pointerenter")
      point(sub_content, "pointerleave")

      expect(page).to have_css("#{sub_content}[data-state=closed]", visible: :all)
    end
  end
end
