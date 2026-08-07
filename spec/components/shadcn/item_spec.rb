# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Item::Group::Component, type: :component do
  it "marks slotted items as list items, which role=list obliges" do
    render_inline(described_class.new) do |group|
      group.with_item { "One" }
    end

    expect(page).to have_css("[data-slot=item-group][role=list] > [data-slot=item][role=listitem]")
  end

  # The bare form stays available: it is what upstream's markup is, and a caller
  # who is not building a list should not be forced into list semantics.
  it "leaves an explicitly rendered item alone" do
    render_inline(Shadcn::Item::Component.new) { "One" }

    expect(page).to have_no_css("[role=listitem]")
  end

  # `items` renders before block content (Card::Component's pattern), so a
  # separator placed as block content between two `with_item` calls would land
  # after both instead of between them. Routing it through the same slot keeps
  # call order — and it must not pick up `role=listitem`, which is for `Item`.
  it "keeps a separator between items in call order without marking it a list item" do
    render_inline(described_class.new) do |group|
      group.with_item { "One" }
      group.with_separator
      group.with_item { "Two" }
    end

    expect(page).to have_css(
      "[data-slot=item-group] > :nth-child(1)[data-slot=item][role=listitem]"
    )
    expect(page).to have_css(
      "[data-slot=item-group] > :nth-child(2)[data-slot=item-separator][role=none]"
    )
    expect(page).to have_css(
      "[data-slot=item-group] > :nth-child(3)[data-slot=item][role=listitem]"
    )
  end
end
