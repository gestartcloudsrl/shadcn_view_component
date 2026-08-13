# frozen_string_literal: true

module Shadcn
  # Base class for every ported shadcn/ui component.
  #
  # It exists to make the React → ViewComponent mapping mechanical:
  #
  #   React                                  Ruby
  #   ------------------------------------   ---------------------------------------
  #   cva(base, {variants, defaultVariants})  style { base {} variants {} defaults {} }
  #   cn(...)                                 TailwindMerge, wired as the style postprocessor
  #   data-slot="card-header"                 slot_name :"card-header"
  #   <div {...props} />                      **attributes, splatted through Rails' tag builder
  #   asChild                                 as: :a / as: :span
  #
  # A component that is a single element carrying `data-slot` + classes needs no
  # template at all: the inherited `#call` renders it. Components whose markup is
  # richer (an icon, a nested wrapper, an indicator) get a sidecar
  # `component.html.erb`, which overrides `#call`.
  class ApplicationViewComponent < ViewComponent::Base
    include ViewComponentContrib::StyleVariants

    # `cn()`: concatenate, then let tailwind-merge drop conflicting utilities so
    # that classes passed in by the caller win — exactly like shadcn's helper.
    style_config.postprocess_with { |classes| ShadcnViewComponent.cn(classes) }

    # Elements that must not be given a block/closing tag.
    VOID_TAGS = %i[area base br col embed hr img input link meta source track wbr].freeze

    class << self
      # The element rendered by default, i.e. the tag in the TSX source.
      def default_tag(value = nil)
        return @default_tag = value.to_sym if value

        @default_tag ||= superclass.respond_to?(:default_tag) ? superclass.default_tag : :div
      end

      # The `data-slot` value shadcn stamps on this part. Inherited, so that
      # specialisations such as PaginationPrevious keep PaginationLink's slot.
      def slot_name(value = nil)
        return @slot_name = value.to_s if value
        return @slot_name if defined?(@slot_name)

        @slot_name = superclass.respond_to?(:slot_name) ? superclass.slot_name : nil
      end
    end

    attr_reader :attributes

    # @param as [Symbol, String, nil] render a different element (shadcn's `asChild`)
    # @param attributes [Hash] anything else is forwarded to the element, like `{...props}`
    def initialize(as: nil, **attributes)
      @as = as
      @attributes = attributes
    end

    def call
      render_element(body: content)
    end

    def tag_name
      (@as || self.class.default_tag).to_sym
    end

    # Renders the component's root element. `defaults` are the attributes the
    # component itself contributes; see `#element_attributes` for how they rank
    # against the caller's.
    #
    # The body comes either from a block (templates: `<%= render_element do %>`)
    # or from `body:` — `#call` passes ViewComponent's already-captured `content`
    # that way, because re-capturing it here would swallow it.
    def render_element(body: nil, **defaults, &block)
      attrs = element_attributes(**defaults)
      return tag.public_send(tag_name, **attrs) if VOID_TAGS.include?(tag_name)

      content_tag(tag_name, block ? capture(&block) : body, attrs)
    end

    # The full attribute hash for the root element.
    #
    # Precedence, lowest to highest: the `data-slot` marker, then the component's
    # own `defaults` (what subclasses pass up through `super`), then whatever the
    # caller gave us. The caller winning is the point — it is what `{...props}`
    # does in every shadcn component, where the spread comes last.
    def element_attributes(**defaults)
      base = { "data-slot" => self.class.slot_name }.compact
      merged = merge_attributes(base, defaults, attributes)
      merged["class"] = css_classes(merged.delete("class"))
      merged.compact
    end

    # Compiles the cva-equivalent style set. Caller classes go last so
    # tailwind-merge resolves conflicts in their favour. Parts that carry no
    # classes of their own still have to pass the caller's through.
    #
    # Without caller classes the result depends only on the component class and
    # its variants, and the style blocks are static once loaded — so it is
    # computed once. That is not just a saving on the merge: it keeps the
    # library's own class strings out of tailwind_merge's LRU, which is a fixed
    # size shared with everything the caller varies.
    def css_classes(extra = nil)
      return compile_classes(extra) if extra.present?

      ShadcnViewComponent.class_cache.fetch_or_store([ self.class.name, style_variants ]) do
        compile_classes(nil)
      end
    end

    # Overridden by components that expose variants (button, badge, alert, …).
    def style_variants
      {}
    end

    # The user-visible strings the components render, looked up under
    # `shadcn_view_component.*` with shadcn's English as the default — so the
    # gem works untranslated and a host app can override any key.
    def shadcn_t(key, **interpolations)
      I18n.t("shadcn_view_component.#{key}", **interpolations)
    end

    # Combines inline styles without dropping whatever the caller passed.
    def merged_style(*declarations)
      [ attributes[:style], *declarations ].compact.reject(&:empty?).join(";").presence
    end

    # Radix's context-only roots (Dialog, Popover, Select, …) render no element
    # at all. We need somewhere to hang the Stimulus controller, so those roots
    # emit a wrapper that is invisible to layout.
    CONTENTS_STYLE = "display:contents"

    private

    def compile_classes(extra)
      compiled = style(**style_variants, class: extra)
      (compiled || ShadcnViewComponent.cn(extra)).presence
    end

    # Shallow merge, with three exceptions that are combined rather than
    # replaced: `data:`/`aria:` hashes, `class`, and `data-action` — Stimulus
    # reads a space-separated list, so an action passed in by the caller adds to
    # the component's own instead of silently replacing it.
    #
    # Keys are normalised to strings so `class:` and `"class"` cannot end up as
    # two separate attributes.
    def merge_attributes(*hashes)
      hashes.compact.map { |hash| normalize_attributes(hash) }.reduce({}) do |acc, hash|
        hash.each do |name, value|
          case name
          when "data", "aria"
            acc[name] = (acc[name] || {}).merge(value || {})
          when "class"
            acc["class"] = [ acc["class"], value ].compact
          when "data-action"
            append_action(acc, value)
          else
            acc[name] = value
          end
        end
        acc
      end
    end

    # Stringifies the keys and lifts `data: { action: … }` — the idiomatic Rails
    # spelling — out to a top-level `data-action`, so both spellings reach the
    # concatenation rule above. Without this the two forms land in different
    # branches and the element ends up with the attribute twice, which is invalid
    # HTML: the browser keeps the first and the other action never fires.
    def normalize_attributes(hash)
      hash.each_with_object({}) do |(key, value), normalized|
        name = key.to_s

        if name == "data" && value.is_a?(Hash)
          data = value.transform_keys(&:to_s)
          action = data.delete("action")

          append_action(normalized, action) if action
          normalized["data"] = data unless data.empty?
        elsif name == "data-action"
          append_action(normalized, value)
        else
          normalized[name] = value
        end
      end
    end

    def append_action(hash, value)
      hash["data-action"] = [ hash["data-action"], value ].compact.join(" ")
    end
  end
end
