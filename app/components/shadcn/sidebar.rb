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

    sidebar_part :group, slot: "sidebar-group",
                 classes: "relative flex w-full min-w-0 flex-col p-2"

    sidebar_part :group_label, slot: "sidebar-group-label",
                 classes: "flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium " \
                          "text-sidebar-foreground/70 ring-sidebar-ring outline-hidden " \
                          "transition-[margin,opacity] duration-200 ease-linear " \
                          "focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0 " \
                          "group-data-[collapsible=icon]:-mt-8 " \
                          "group-data-[collapsible=icon]:opacity-0"

    sidebar_part :group_action, slot: "sidebar-group-action", tag: :button,
                 classes: "absolute top-3.5 right-3 flex aspect-square w-5 items-center " \
                          "justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring " \
                          "outline-hidden transition-transform hover:bg-sidebar-accent " \
                          "hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 " \
                          "[&>svg]:shrink-0 after:absolute after:-inset-2 md:after:hidden " \
                          "group-data-[collapsible=icon]:hidden"

    sidebar_part :group_content, slot: "sidebar-group-content",
                 classes: "w-full text-sm"

    sidebar_part :menu, slot: "sidebar-menu", tag: :ul,
                 classes: "flex w-full min-w-0 flex-col gap-1"

    sidebar_part :menu_item, slot: "sidebar-menu-item", tag: :li,
                 classes: "group/menu-item relative"

    sidebar_part :menu_badge, slot: "sidebar-menu-badge",
                 classes: "pointer-events-none absolute right-1 flex h-5 min-w-5 items-center " \
                          "justify-center rounded-md px-1 text-xs font-medium " \
                          "text-sidebar-foreground tabular-nums select-none " \
                          "peer-hover/menu-button:text-sidebar-accent-foreground " \
                          "peer-data-[active=true]/menu-button:text-sidebar-accent-foreground " \
                          "peer-data-[size=sm]/menu-button:top-1 " \
                          "peer-data-[size=default]/menu-button:top-1.5 " \
                          "peer-data-[size=lg]/menu-button:top-2.5 " \
                          "group-data-[collapsible=icon]:hidden"

    sidebar_part :menu_sub, slot: "sidebar-menu-sub", tag: :ul,
                 classes: "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l " \
                          "border-sidebar-border px-2.5 py-0.5 group-data-[collapsible=icon]:hidden"

    sidebar_part :menu_sub_item, slot: "sidebar-menu-sub-item", tag: :li,
                 classes: "group/menu-sub-item relative"

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
