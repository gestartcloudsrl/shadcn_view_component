# frozen_string_literal: true

require "spec_helper"

# This component is this port's own — `sonner.tsx` is forty lines of
# configuration and emits no markup at all — so there is no parity to lean on
# and the behaviour is the whole of what is checked.
#
# What it has to do: show what the server sends with the page, show what
# arrives afterwards without being told, count down, stop counting while
# somebody is reading, and go away.
RSpec.describe "Toaster", :js do
  let(:list) { "#shadcn-toasts" }
  let(:toast) { "[data-slot=toast]" }

  def toasts = all(toast, visible: :all)

  def tops
    page.evaluate_script(<<~JS)
      Object.fromEntries([...document.querySelectorAll("[data-slot=toast]")]
        .map((t) => [ t.querySelector("[data-slot=toast-title]").textContent,
                      Math.round(t.getBoundingClientRect().top) ]))
    JS
  end

  # Open means both halves of it: every toast readable rather than a shape
  # behind the front one, and standing apart rather than piled.
  def expanded?
    page.evaluate_script(<<~JS)
      (() => {
        const toasts = [...document.querySelectorAll("[data-slot=toast]")]
        const readable = toasts.every((t) => t.children[0].style.opacity === "1")
        const boxes = toasts.map((t) => t.getBoundingClientRect()).sort((a, b) => a.top - b.top)
        const apart = boxes.every((box, i) => i === 0 || boxes[i - 1].bottom <= box.top + 1)
        return readable && apart
      })()
    JS
  end

  def raise_toast(detail)
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent("shadcn--toast", { detail: #{detail.to_json} }))
    JS
  end

  # The clock is real, so the examples that are about it say how long. Anything
  # else uses a duration of 0, which this component reads as "no clock".
  def visit_toaster(duration: 0)
    visit "/lookbook/preview/shadcn/toaster/default"
    expect(page).to have_css("[data-slot=toaster]", visible: :all)
    wait_for_stimulus
    page.execute_script(<<~JS)
      document.querySelector("[data-slot=toaster]")
        .setAttribute("data-shadcn--toaster-duration-value", #{duration})
    JS
  end

  before { visit_toaster }

  describe "the JavaScript route" do
    it "raises a toast carrying what it was given", :aggregate_failures do
      raise_toast(title: "Changes saved", description: "All of them", variant: "success")

      expect(page).to have_css(toast, count: 1)
      expect(find("#{toast} [data-slot=toast-title]").text).to eq("Changes saved")
      expect(find("#{toast} [data-slot=toast-description]").text).to eq("All of them")
      expect(find(toast)["data-variant"]).to eq("success")
    end

    # A variant is not only an attribute: it decides whether there is an icon at
    # all. Setting `data-variant` on a shape that never had one leaves a toast
    # with nothing to say which kind it is, which is how this first shipped.
    it "gives each variant its own icon, and the plain one none", :aggregate_failures do
      raise_toast(title: "Saved", variant: "success")
      raise_toast(title: "Gone wrong", variant: "error")
      raise_toast(title: "Just so you know")

      icons = toasts.map { |t| t.all("[data-slot=toast-icon]", visible: :all).size }

      expect(icons).to eq([ 1, 1, 0 ])
    end

    it "leaves out a description that was not given" do
      raise_toast(title: "Alone")

      expect(page).to have_css("#{toast} [data-slot=toast-title]")
      expect(page).to have_no_css("#{toast} [data-slot=toast-description]")
    end
  end

  # The half sonner does not have, and the reason this component is a component:
  # in a Rails app the thing that knows a toast is needed is usually the server.
  describe "the server route" do
    it "counts down a toast that arrived in the page's own HTML" do
      page.execute_script(<<~JS)
        const list = document.querySelector(#{list.to_json})
        const template = document.querySelector("[data-shadcn--toaster-target=template][data-variant=info]")
        const toast = template.content.firstElementChild.cloneNode(true)
        toast.querySelector("[data-slot=toast-title]").textContent = "Appended"
        toast.dataset.duration = 300
        list.appendChild(toast)
      JS

      expect(page).to have_css(toast, count: 1)
      # Nothing told the controller this happened: it watches the list, which is
      # what lets `turbo_stream.append` work without knowing this exists.
      expect(page).to have_no_css(toast, wait: 3)
    end
  end

  describe "the clock" do
    it "takes a toast away when its time is up" do
      raise_toast(title: "Brief", duration: 300)

      expect(page).to have_css(toast, count: 1)
      expect(page).to have_no_css(toast, wait: 3)
    end

    # Reading one is exactly when it must not vanish.
    it "stops counting while the pointer is on the stack" do
      raise_toast(title: "Read me", duration: 400)
      expect(page).to have_css(toast, count: 1)

      find(list).hover
      sleep 1.2

      expect(page).to have_css(toast, count: 1)
    end

    it "starts counting again once the pointer leaves" do
      raise_toast(title: "Read me", duration: 300)
      find(list).hover
      sleep 0.6
      expect(page).to have_css(toast, count: 1)

      page.driver.browser.action.move_to_location(5, 5).perform

      expect(page).to have_no_css(toast, wait: 3)
    end

    # A toast that is waiting on something has no business disappearing on a
    # clock — it is dismissed by whatever it was waiting for.
    it "keeps a loading toast" do
      raise_toast(title: "Uploading", variant: "loading", duration: 300)

      expect(page).to have_css(toast, count: 1)
      sleep 1
      expect(page).to have_css(toast, count: 1)
    end
  end

  # A duration of 0 means "no clock", and `Number(x) || fallback` reads a 0 as
  # "not given" and hands back the default — the opposite. Found while looking
  # at the page: three toasts raised with `duration: 0` had all gone by the time
  # the screenshot was taken.
  it "keeps a toast asked to stay" do
    visit_toaster(duration: 200)
    raise_toast(title: "I am staying", duration: 0)

    expect(page).to have_css(toast, count: 1)
    sleep 0.8
    expect(page).to have_css(toast, count: 1)
  end

  # Reported from the gallery: sonner stacks its toasts one behind another and
  # fans them out under the pointer, where this piled them in a column.
  describe "the stack" do
    before do
      3.times { |i| raise_toast(title: "Toast #{i}") }
      expect(page).to have_css(toast, count: 3)
    end

    it "keeps the newest in front and the rest behind it, smaller and quiet", :aggregate_failures do
      placed = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(#{toast.to_json})].map((t) => ({
          transform: t.style.transform,
          z: Number(t.style.zIndex),
          content: t.children[0].style.opacity
        }))
      JS

      # The list runs oldest to newest; the newest is the front one.
      front = placed.last
      expect(front["transform"]).to include("translateY(0px)").and include("scale(1)")
      expect(front["content"]).to eq("1")

      behind = placed.first
      expect(behind["transform"]).not_to include("translateY(0px)")
      expect(behind["content"]).to eq("0")
      expect(behind["z"]).to be < front["z"]
    end

    it "fans them out under the pointer, and grows the area with them", :aggregate_failures do
      closed = page.evaluate_script("Math.round(document.querySelector(#{list.to_json}).getBoundingClientRect().height)")

      find(list).hover

      opened = page.evaluate_script("Math.round(document.querySelector(#{list.to_json}).getBoundingClientRect().height)")
      expect(opened).to be > closed

      readable = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(#{toast.to_json})].map((t) => t.children[0].style.opacity)
      JS
      expect(readable).to all(eq("1"))

      # And they stand apart. A growing box with the toasts still piled on top
      # of each other looks the same from the outside, which is what the first
      # version of this example could not tell.
      boxes = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(#{toast.to_json})]
          .map((t) => t.getBoundingClientRect())
          .map((r) => [Math.round(r.top), Math.round(r.bottom)])
          .sort((a, b) => a[0] - b[0])
      JS

      boxes.each_cons(2) { |above, below| expect(above[1]).to be <= below[0] + 1 }
    end

    # Reported from the gallery: moving the pointer from one toast to the next
    # collapsed the stack for an instant.
    #
    # The region is `pointer-events: none` so the page underneath stays usable
    # around a toast, and each toast turns them back on for itself — which
    # leaves the 14px between two toasts as a hole. A pointer crossing one
    # hit-tests through to the page, leaves the list, and the stack shuts and
    # reopens as it lands on the next.
    #
    # Asked of the page rather than reasoned about: what is under the point
    # halfway between two toasts?
    it "keeps the pointer when it crosses from one toast to the next", :aggregate_failures do
      find(list).hover

      under = page.evaluate_script(<<~JS)
        (() => {
          const boxes = [...document.querySelectorAll(#{toast.to_json})]
            .map((t) => t.getBoundingClientRect())
            .sort((a, b) => a.top - b.top)
          const region = document.querySelector("[data-slot=toaster]")

          return boxes.slice(0, -1).map((box, i) => {
            const y = (box.bottom + boxes[i + 1].top) / 2
            const x = box.left + box.width / 2
            const hit = document.elementFromPoint(x, y)
            return { gap: Math.round(boxes[i + 1].top - box.bottom),
                     inside: !!hit && region.contains(hit) }
          })
        })()
      JS

      expect(under).not_to be_empty
      under.each do |gap|
        expect(gap["gap"]).to be > 0
        expect(gap["inside"]).to be(true)
      end
    end

    # And gives them back when it closes. The region is `pointer-events: none`
    # so that a corner of the page is not quietly covered by an invisible box;
    # holding the pointer open all the time would trade the flicker for that.
    it "lets the page through again once the stack is closed", :aggregate_failures do
      free = page.evaluate_script(<<~JS)
        (() => {
          const list = document.querySelector(#{list.to_json})
          const box = list.getBoundingClientRect()
          const region = document.querySelector("[data-slot=toaster]")
          // The strip the peeking toasts are lifted out of, at the far edge of
          // the stack from the front one.
          const hit = document.elementFromPoint(box.left + 2, box.top + 2)
          return { events: getComputedStyle(list).pointerEvents,
                   inside: !!hit && region.contains(hit) }
        })()
      JS

      expect(free["events"]).to eq("none")
      expect(free["inside"]).to be(false)
    end

    it "holds every toast inside the area the pointer has to stay in", :aggregate_failures do
      find(list).hover

      inside = page.evaluate_script(<<~JS)
        (() => {
          const box = document.querySelector(#{list.to_json}).getBoundingClientRect()
          return [...document.querySelectorAll(#{toast.to_json})].map((t) => {
            const r = t.getBoundingClientRect()
            return { above: Math.round(box.top - r.top), below: Math.round(r.bottom - box.bottom) }
          })
        })()
      JS

      inside.each do |toast_box|
        expect(toast_box["above"]).to be <= 1
        expect(toast_box["below"]).to be <= 1
      end
    end

    # Reported from the gallery: closing one of an open stack shut the whole
    # thing instead of letting the rest close the gap.
    #
    # The stack is anchored at its edge, so it is the ones *behind* the toast
    # that goes which have somewhere to move — closing the middle one is the
    # case with something to see.
    it "closes the gap a dismissed toast leaves, and stays open", :aggregate_failures do
      find(list).hover
      before = tops

      all("#{toast} button[aria-label]")[1].click
      expect(page).to have_css(toast, count: 2)

      expect(tops["Toast 0"]).to be > before["Toast 0"]
      expect(expanded?).to be(true)
    end

    # The half of that which the harness hides. A toast leaves on a transition,
    # not on keyframes, and Capybara's AnimationDisabler removes transitions
    # outright (`transition: none !important`) — so in every other example here a
    # dismissed toast is out of the DOM in the tick it was closed, and whether
    # the rest waited for it cannot be seen. Handing the transition back inline
    # is the trick `force_animations` plays for keyframes; because what was
    # removed is the property and not only the duration, both come back.
    it "closes the gap while the dismissed toast is still fading", :aggregate_failures do
      all(toast, visible: :all).each do |element|
        page.execute_script(<<~JS, element)
          arguments[0].style.setProperty("transition", "all 2s", "important")
        JS
      end
      find(list).hover

      # Where each one is *told* to be, not where it has got to: the move is a
      # transition too, so the painted position is halfway through it.
      placed = <<~JS
        Object.fromEntries([...document.querySelectorAll("[data-slot=toast]")]
          .map((t) => [ t.querySelector("[data-slot=toast-title]").textContent, t.style.transform ]))
      JS
      before = page.evaluate_script(placed)

      all("#{toast} button[aria-label]")[1].click

      expect(page).to have_css("#{toast}[data-state=closed]", visible: :all)
      expect(page.evaluate_script(placed)["Toast 0"]).not_to eq(before["Toast 0"])

      # And it is fading rather than waiting: `place()` writes an inline opacity
      # on every toast, and an inline style beats the class that fades this one
      # out — so unless the property is handed back there is no transition here
      # at all, and the queue that waits for one takes the toast away at once.
      leaving = page.evaluate_script(<<~JS)
        document.querySelector("[data-slot=toast][data-state=closed]")
          .getAnimations().map((a) => a.transitionProperty)
      JS
      expect(leaving).to include("opacity")
    end

    # And the one where nothing moves is the one that shut it hardest: the box
    # is as tall as the stack, so the toast furthest from the edge is holding
    # the far end of it open — the box shrinks past the pointer still on it,
    # and the browser calls that leaving.
    it "stays open when the toast the pointer is on is the one dismissed" do
      find(list).hover

      all("#{toast} button[aria-label]").first.click
      expect(page).to have_css(toast, count: 2)

      expect(expanded?).to be(true)
    end

    it "closes the stack again once the pointer leaves" do
      find(list).hover
      opened = page.evaluate_script("Math.round(document.querySelector(#{list.to_json}).getBoundingClientRect().height)")

      page.driver.browser.action.move_to_location(5, 5).perform

      expect(page.document).to have_content("")
      closed = page.evaluate_script("Math.round(document.querySelector(#{list.to_json}).getBoundingClientRect().height)")
      expect(closed).to be < opened
    end
  end

  it "closes when its dismiss button is pressed" do
    raise_toast(title: "Go away")
    expect(page).to have_css(toast, count: 1)

    find("#{toast} button[aria-label]").click

    expect(page).to have_no_css(toast)
  end

  # The region has to announce itself, and politely: a toast that interrupts a
  # screen reader mid-sentence is worse than one nobody notices.
  it "is a polite live region with a name", :aggregate_failures do
    region = find("[data-slot=toaster]", visible: :all)

    expect(region["aria-live"]).to eq("polite")
    expect(region["aria-label"]).to be_present
    expect(find(list, visible: :all).tag_name).to eq("ol")
  end
end
