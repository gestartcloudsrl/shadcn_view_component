# frozen_string_literal: true

require "spec_helper"

# The palette. Items are rendered by the server; what the controller does is
# filter, *rank* and walk them — and the ranking is what separates this from the
# searchable select, which filters a list its caller ordered and keeps that
# order.
RSpec.describe "Command", :js do
  let(:command) { "[data-slot=command]" }
  let(:input) { "[data-slot=command-input]" }
  let(:item) { "[data-slot=command-item]" }

  def visible_items
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#{item}")]
        .filter((option) => !option.hidden && !option.closest("[cmdk-group][hidden]"))
        .map((option) => option.textContent.trim().replace(/\\s+/g, " "))
    JS
  end

  def type(text)
    find(input).set(text)
  end

  # Squished, because an item holds an icon, a label and a shortcut on three
  # lines of ERB and none of that is what it reads as.
  def selected
    page.evaluate_script(<<~JS)
      document.querySelector("#{item}[data-selected=true]")?.textContent.trim().replace(/\\s+/g, " ")
    JS
  end

  describe "searching" do
    before do
      visit "/lookbook/preview/shadcn/command/default"
      wait_for_stimulus
    end

    it "starts with everything, in the order the server rendered it" do
      expect(visible_items).to eq([ "Calendar", "Search Emoji", "Calculator", "Profile ⌘P", "Billing ⌘B", "Settings ⌘S" ])
    end

    it "drops what does not match" do
      type("cal")

      expect(visible_items).to eq([ "Calendar", "Calculator" ])
    end

    # `keywords:` are searched and never shown, which is how an item is found by
    # a word that is not in it.
    it "finds an item by a keyword it does not display" do
      type("invoice")

      expect(visible_items).to eq([ "Billing ⌘B" ])
    end

    # By heading rather than by position: the groups are reordered too, so the
    # one still holding something has moved to the front by the time this looks.
    it "hides a group once everything in it has gone", :aggregate_failures do
      type("profile")

      groups = page.evaluate_script(<<~JS)
        Object.fromEntries([...document.querySelectorAll("[cmdk-group]")].map((group) => [
          group.querySelector("[cmdk-group-heading]").textContent, group.hidden
        ]))
      JS
      expect(groups).to eq("Suggestions" => true, "Settings" => false)
      expect(visible_items).to eq([ "Profile ⌘P" ])
    end

    # And the group with the best answer in it comes first, for the same reason
    # the answer does.
    it "puts the group holding the best match first" do
      type("billing")

      expect(page.evaluate_script(<<~JS)).to eq("Settings")
        document.querySelector("[cmdk-group]:not([hidden]) [cmdk-group-heading]").textContent
      JS
    end

    it "shows the empty state when nothing matches at all", :aggregate_failures do
      type("zzzz")

      expect(visible_items).to be_empty
      expect(page).to have_css("[data-slot=command-empty]", text: "No results found.")
    end

    it "goes back to the server's order when the query is cleared" do
      type("cal")
      type("")

      expect(visible_items).to eq([ "Calendar", "Search Emoji", "Calculator", "Profile ⌘P", "Billing ⌘B", "Settings ⌘S" ])
    end
  end

  # The reason the scorer was ported rather than replaced with a substring test:
  # a palette answers "what did you mean", so the answer has to come first.
  describe "ranking" do
    before do
      visit "/lookbook/preview/shadcn/command/ranking"
      wait_for_stimulus
    end

    it "puts a match at the start of a word above one in the middle", :aggregate_failures do
      type("gp")

      expect(visible_items.first).to eq("Group Policy")
      expect(visible_items).to include("Groups")
    end

    it "ranks an exact run above a scattered one" do
      type("gr")

      expect(visible_items.first).to eq("Groups")
    end
  end

  describe "the keyboard" do
    before do
      visit "/lookbook/preview/shadcn/command/default"
      wait_for_stimulus
      find(input).click
    end

    it "starts on the first item" do
      expect(selected).to eq("Calendar")
    end

    it "walks down and up", :aggregate_failures do
      find(input).send_keys(:down)
      expect(selected).to eq("Search Emoji")

      find(input).send_keys(:up)
      expect(selected).to eq("Calendar")
    end

    # A disabled item is not a stop on the way, which is what `visibleItems`
    # filtering on `data-disabled` is for.
    it "steps over a disabled item" do
      find(input).send_keys(:down, :down)

      expect(selected).to eq("Profile ⌘P")
    end

    # cmdk's default, and a palette is a ring: the first item is one press up
    # from the last.
    it "wraps around at the ends" do
      find(input).send_keys(:up)

      expect(selected).to eq("Settings ⌘S")
    end

    it "follows what is left after a search" do
      type("cal")

      expect(selected).to eq("Calendar")
    end

    it "says what Enter chose" do
      page.execute_script(<<~JS)
        window.__chosen = []
        document.addEventListener("shadcn--command:select", (e) => window.__chosen.push(e.detail.value))
      JS

      find(input).send_keys(:down, :enter)

      expect(page.evaluate_script("window.__chosen")).to eq([ "Search Emoji" ])
    end
  end

  # The virtual focus: the caret stays in the input and the list is walked by
  # id, which is the arrangement the searchable select uses too.
  describe "what a screen reader is told" do
    before do
      visit "/lookbook/preview/shadcn/command/default"
      wait_for_stimulus
    end

    it "points the input at the item it would take", :aggregate_failures do
      find(input).click
      find(input).send_keys(:down)

      pointed = find(input)["aria-activedescendant"]
      expect(pointed).to be_present
      expect(find_by_id(pointed).text).to include("Search Emoji")
    end

    it "names the list from the label the caller gave" do
      labelled_by = find("[data-slot=command-list]")["aria-labelledby"]

      expect(find_by_id(labelled_by, visible: :all).text).to eq("Command palette")
    end
  end
end
