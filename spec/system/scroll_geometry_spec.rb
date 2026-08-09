# frozen_string_literal: true

require "spec_helper"

# `shadcn/scroll_geometry.js` is pure — rects in, numbers out — so these are unit
# tests in everything but the runner. There is no runner: this gem has no npm and
# nothing executes its JavaScript outside a browser, so "pure" buys a synthetic
# fixture and direct calls rather than a component to drive.
#
# Real layout is the point. Every one of these functions exists because
# `scrollHeight`, `getBoundingClientRect` and computed padding disagree in ways
# that only a browser produces, and a stubbed rect would assert the stub.
RSpec.describe "scroll geometry", :js do
  # A scroller with room for two of its four rows, a padded content column, and
  # a spacer that is deliberately taller than the rows so anything reading
  # `scrollHeight` instead of the rows gets a different answer.
  let(:fixture) do
    <<~JS
      document.body.innerHTML = ""
      const viewport = document.createElement("div")
      viewport.id = "viewport"
      Object.assign(viewport.style, { height: "200px", overflowY: "auto" })

      const content = document.createElement("div")
      content.id = "content"
      Object.assign(content.style, {
        display: "flex", flexDirection: "column", rowGap: "10px",
        paddingTop: "20px", paddingBottom: "30px"
      })

      for (let i = 0; i < 4; i++) {
        const item = document.createElement("div")
        item.dataset.messageId = `m${i}`
        if (i === 2) item.dataset.scrollAnchor = "true"
        item.style.height = "100px"
        item.style.flexShrink = "0"
        content.appendChild(item)
      }

      const spacer = document.createElement("div")
      spacer.id = "spacer"
      spacer.style.height = "500px"
      spacer.style.flexShrink = "0"
      content.appendChild(spacer)

      viewport.appendChild(content)
      document.body.appendChild(viewport)
    JS
  end

  # `import()` because the module is an ES module served through the importmap,
  # which `pin_all_from` already covers — no pin was added for it.
  def geometry(expression)
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const viewport = document.getElementById("viewport")
      const content = document.getElementById("content")
      const spacer = document.getElementById("spacer")
      import("shadcn/scroll_geometry")
        .then((g) => done(#{expression}))
        .catch((error) => done(`ERROR: ${error.message}`))
    JS
  end

  before do
    visit_preview(:card)
    page.execute_script(fixture)
  end

  describe "reading the rows" do
    it "returns the items and leaves the spacer out" do
      expect(geometry("g.getMessageScrollerItems(content, spacer).length")).to eq(4)
    end

    it "counts the spacer when it is not named, which is what the argument is for" do
      expect(geometry("g.getMessageScrollerItems(content, null).length")).to eq(5)
    end
  end

  # The one that earns its own function. `scrollHeight` here is the four rows,
  # the gaps, the padding *and* the 500px spacer; the content's real bottom is
  # everything except the spacer.
  describe "the content's bottom" do
    it "measures the rows rather than the scroll height" do
      bottom = geometry("g.getContentBottom({ content, spacer, viewport })")
      scroll_height = page.evaluate_script("document.getElementById('viewport').scrollHeight")

      # 20 top padding + 4×100 + 3×10 gaps + 30 bottom padding.
      expect(bottom).to be_within(1).of(480)
      expect(scroll_height).to be > bottom + 400
    end
  end

  describe "which way there is left to scroll" do
    it "reports neither end at rest when the threshold swallows the difference" do
      state = geometry(
        "JSON.stringify(g.getMessageScrollerScrollable(" \
        "{ content, scrollEdgeThreshold: 8, spacer, viewport }))"
      )

      expect(JSON.parse(state)).to eq("start" => false, "end" => true)
    end

    it "flips once the content's bottom is reached, ignoring the spacer below it" do
      page.execute_script("document.getElementById('viewport').scrollTop = 280")
      state = geometry(
        "JSON.stringify(g.getMessageScrollerScrollable(" \
        "{ content, scrollEdgeThreshold: 8, spacer, viewport }))"
      )

      expect(JSON.parse(state)).to eq("start" => true, "end" => false)
    end
  end

  describe "placing an element" do
    # The assertion that catches a sign error: `getElementTop` is in the
    # scroller's own coordinates, so scrolling must not change it.
    it "gives the same top before and after scrolling" do
      before_scroll = geometry("g.getElementTop(content.children[2], viewport)")
      page.execute_script("document.getElementById('viewport').scrollTop = 150")
      after_scroll = geometry("g.getElementTop(content.children[2], viewport)")

      expect(after_scroll).to be_within(1).of(before_scroll)
    end

    it "moves with the viewport when asked for the viewport's coordinates" do
      page.execute_script("document.getElementById('viewport').scrollTop = 0")
      at_rest = geometry("g.getElementViewportTop(content.children[2], viewport)")
      page.execute_script("document.getElementById('viewport').scrollTop = 150")
      scrolled = geometry("g.getElementViewportTop(content.children[2], viewport)")

      expect(at_rest - scrolled).to be_within(1).of(150)
    end

    # `nearest` is the only alignment that can answer "stay where you are", and
    # the only one where getting the comparison backwards still returns a
    # plausible number.
    it "leaves nearest alone when the element is already inside the viewport" do
      page.execute_script("document.getElementById('viewport').scrollTop = 220")
      top = geometry(
        "g.getElementScrollTop({ align: 'nearest', element: content.children[2], " \
        "scrollMargin: 0, spacer, viewport })"
      )

      expect(top).to eq(220)
    end
  end

  describe "the anchors" do
    it "finds the one that arrived, and not one that was already there" do
      expect(geometry("g.getNewScrollAnchor(g.getMessageScrollerItems(content, spacer), 0)?.dataset.messageId"))
        .to eq("m2")
      expect(geometry("g.getNewScrollAnchor(g.getMessageScrollerItems(content, spacer), 3)"))
        .to be_nil
    end

    it "says when more than one arrived at once, which cannot all be scrolled to" do
      expect(geometry("g.hasMultipleNewScrollAnchors(g.getMessageScrollerItems(content, spacer), 0)"))
        .to be(false)

      page.execute_script("document.getElementById('content').children[3].dataset.scrollAnchor = 'true'")

      expect(geometry("g.hasMultipleNewScrollAnchors(g.getMessageScrollerItems(content, spacer), 0)"))
        .to be(true)
    end

    it "skips an anchor the caller has already handled" do
      expect(geometry(
        "g.getUnanchoredScrollAnchor(g.getMessageScrollerItems(content, spacer), " \
        "{ has: (element) => element === content.children[2] })"
      )).to be_nil
    end
  end

  # `normal` is what `rowGap` computes to when only `gap` is set, and
  # `Number.parseFloat` on it is `NaN` — which would spread through every sum it
  # reached rather than failing where it happened.
  describe "reading a computed length" do
    it "falls back from rowGap to gap" do
      expect(geometry("g.getFlexGap(content)")).to eq(10)

      page.execute_script(<<~JS)
        const c = document.getElementById("content")
        c.style.rowGap = ""
        c.style.gap = "14px"
      JS

      expect(geometry("g.getFlexGap(content)")).to eq(14)
    end

    it "answers 0 rather than NaN for an element with nothing set" do
      expect(geometry("g.getFlexGap(document.body)")).to eq(0)
    end

    it "reads the content's block padding through the spacer" do
      padding = geometry("JSON.stringify(g.getContentBlockPadding(spacer))")

      expect(JSON.parse(padding)).to eq("start" => 20, "end" => 30)
    end
  end
end
