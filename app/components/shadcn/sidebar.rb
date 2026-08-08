# frozen_string_literal: true

module Shadcn
  # The parts of the Sidebar family that are an element with its two attributes
  # and a fixed set of classes. Anything with variants, slots or markup of its
  # own keeps its own `component.rb`.
  #
  # This family needs a macro of its own because shadcn stamps a *second*
  # attribute on every one of its 24 parts — `data-sidebar="header"` beside
  # `data-slot="sidebar-header"` — and `part` declares a slot, classes and a tag
  # and deliberately nothing else. Taken literally that meant 23 files of eleven
  # lines each, which is precisely what `part` was written to remove.
  #
  # `sidebar_part` is not `part` widened to take attributes; that was considered
  # and rejected in decisions/01-architecture.md, on the grounds that it turns a
  # lookup table into a configuration language. It adds exactly one attribute and
  # *derives* it: measured across the whole vendored source, `data-sidebar` is
  # `data-slot` without its `sidebar-` prefix in 21 of 21 cases, no exceptions.
  # A rule, not a parameter. If upstream ever breaks it, one file changes.
  module Sidebar
    extend Parts

    # Declares a part and stamps the derived `data-sidebar` on it. Caller
    # attributes still win, as they do everywhere else here.
    def self.sidebar_part(name, slot:, **options)
      marker = slot.to_s.delete_prefix("sidebar-")

      part(name, slot:, **options).tap do |component|
        component.define_method(:element_attributes) do |**defaults|
          super(**{ "data-sidebar" => marker }.merge(defaults))
        end
      end
    end

    sidebar_part :header, slot: "sidebar-header", classes: "flex flex-col gap-2 p-2"

    sidebar_part :footer, slot: "sidebar-footer", classes: "flex flex-col gap-2 p-2"

    sidebar_part :content, slot: "sidebar-content",
                           classes: "flex min-h-0 flex-1 flex-col gap-2 overflow-auto " \
                                    "group-data-[collapsible=icon]:overflow-hidden"

    # The one part upstream stamps with `data-slot` alone, so it takes the plain
    # macro and must not gain a `data-sidebar`.
    part :inset, slot: "sidebar-inset", tag: :main,
                 classes: "relative flex w-full flex-1 flex-col bg-background " \
                          "md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 " \
                          "md:peer-data-[variant=inset]:rounded-xl " \
                          "md:peer-data-[variant=inset]:shadow-sm " \
                          "md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2"
  end
end
