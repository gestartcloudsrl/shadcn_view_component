# frozen_string_literal: true

# Helpers shared by the component specs. They deliberately work on the rendered
# DOM rather than on the components' internals: what has to match shadcn/ui 1:1
# is the markup, not the Ruby API used to produce it.
module ComponentHelpers
  # The root element of the last `render_inline` call.
  def root
    Nokogiri::HTML5.fragment(rendered_content.to_s).element_children.first
  end

  # Classes of the root element, as a Set, so order is irrelevant.
  def root_classes
    root["class"].to_s.split(/\s+/).to_set
  end

  # Find the element shadcn marks with `data-slot="<name>"`.
  def slot(name)
    Nokogiri::HTML5.fragment(rendered_content.to_s).at_css(%(*[data-slot="#{name}"]))
  end

  # Assert that every class shadcn emits for this part is present. Extra classes
  # are tolerated only when they come from the caller.
  def expect_classes(*expected)
    expect(root_classes).to include(*expected.flat_map { |e| e.split(/\s+/) })
  end
end
