# frozen_string_literal: true

module Shadcn
  # Declares the parts of a family that are nothing but an element carrying a
  # `data-slot` and a fixed set of classes.
  #
  # Most of shadcn's sub-components are exactly that — `CardTitle` is a `<div>`
  # with two classes — and writing each as its own file meant thirteen lines of
  # module nesting around one string. Declared on the family module instead, a
  # whole family reads at a glance, and the class strings stay literal, which is
  # what both the parity spec and Tailwind's scanner need.
  #
  # See `card.rb` for a worked example.
  #
  # Parts with behaviour — variants, slots, extra markup, computed attributes —
  # stay as their own `component.rb`. This is only for the ones that have none.
  module Parts
    # @param name [Symbol] the part, snake_case; `:group_count` becomes
    #   `GroupCount::Component`
    # @param slot [String] the `data-slot` shadcn stamps on it
    # @param classes [String] its base classes
    # @param tag [Symbol] the element, when it is not a `<div>`
    # @param from [Class] a part to specialise instead of building a new one,
    #   for the families shadcn layers on another (Sheet on Dialog)
    def part(name, slot:, classes: nil, tag: nil, from: ApplicationViewComponent)
      namespace = const_set(name.to_s.camelize, Module.new)
      component = namespace.const_set(:Component, Class.new(from))

      # Configured only after `const_set` has named it: StyleVariants derives the
      # style set's name from the class name, and an anonymous class has none.
      component.default_tag(tag) if tag
      component.slot_name(slot)
      component.style { base { classes } } if classes

      component
    end
  end
end
