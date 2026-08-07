# frozen_string_literal: true

require "spec_helper"

# `Typeahead#search` (app/javascript/shadcn/typeahead.js) is a pure function
# over plain items and a current item — it never touches the DOM beyond
# reading `textContent` — so it is driven here directly, with fabricated
# items, rather than through a component.
#
# Two of the four behaviours ported from Radix's findNextItem
# (vendor/radix/ui/select.tsx:1906-1921) are not observable through any
# preview: with only two items sharing an initial in either the select's or
# the dropdown menu's, excluding the current item from the search already
# narrows the candidates to one, so it makes no difference where the wrap
# starts; and re-highlighting the item that is already highlighted looks, in
# the DOM, exactly like not moving at all. Both are real behaviours of the
# function, just not ones a `data-highlighted` assertion in select_spec.rb or
# dropdown_menu_spec.rb can tell apart from a broken version.
RSpec.describe "Typeahead#search", :js do
  # `shadcn/typeahead` resolves through the same importmap Stimulus does, on
  # any page — which page is irrelevant, so this one is arbitrary.
  before { visit_preview(:select) }

  # Runs the given body once `shadcn/typeahead`'s `Typeahead` class is in
  # scope, and returns whatever it passes to `callback`.
  def run_against_typeahead(body)
    page.evaluate_async_script(<<~JS)
      const callback = arguments[arguments.length - 1]
      import("shadcn/typeahead").then(({ Typeahead }) => {
        #{body}
      })
    JS
  end

  it "wraps the search around the current item rather than starting at the top" do
    # Banana and Blueberry both start with "b"; searching from the top of the
    # list would find Banana, but wrapping from the current item, Grapes,
    # reaches Blueberry first — which is the behaviour under test.
    result = run_against_typeahead(<<~JS)
      const items = [
        { textContent: "Apple" },
        { textContent: "Banana" },
        { textContent: "Grapes" },
        { textContent: "Blueberry" }
      ]
      const match = new Typeahead().search("b", items, items[2])
      callback(match && match.textContent)
    JS

    expect(result).to eq("Blueberry")
  end

  it "does not move when the accumulated search matches the current item" do
    result = run_against_typeahead(<<~JS)
      const items = [
        { textContent: "Apple" },
        { textContent: "Banana" },
        { textContent: "Grapes" },
        { textContent: "Blueberry" }
      ]
      const typeahead = new Typeahead()
      typeahead.search("b", items, items[1])
      // Appending "a" makes the buffer "ba", which matches Banana itself —
      // the current item passed on both calls.
      const match = typeahead.search("a", items, items[1])
      callback(match && match.textContent)
    JS

    expect(result).to be_nil
  end
end
