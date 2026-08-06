# frozen_string_literal: true

module Shadcn
  module Tabs
    module Trigger
      # TabsTrigger
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"tabs-trigger"

        style do
          base {
            "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 " \
            "rounded-md border border-transparent px-2 py-1 text-sm font-medium " \
            "whitespace-nowrap text-foreground/60 transition-all " \
            "group-data-[orientation=vertical]/tabs:w-full " \
            "group-data-[orientation=vertical]/tabs:justify-start hover:text-foreground " \
            "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
            "focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none " \
            "disabled:opacity-50 " \
            "group-data-[variant=default]/tabs-list:data-[state=active]:shadow-sm " \
            "group-data-[variant=line]/tabs-list:data-[state=active]:shadow-none " \
            "dark:text-muted-foreground dark:hover:text-foreground " \
            "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
            "[&_svg:not([class*='size-'])]:size-4 " \
            "group-data-[variant=line]/tabs-list:bg-transparent " \
            "group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent " \
            "dark:group-data-[variant=line]/tabs-list:data-[state=active]:border-transparent " \
            "dark:group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent " \
            "data-[state=active]:bg-background data-[state=active]:text-foreground " \
            "dark:data-[state=active]:border-input dark:data-[state=active]:bg-input/30 " \
            "dark:data-[state=active]:text-foreground " \
            "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity " \
            "group-data-[orientation=horizontal]/tabs:after:inset-x-0 " \
            "group-data-[orientation=horizontal]/tabs:after:bottom-[-5px] " \
            "group-data-[orientation=horizontal]/tabs:after:h-0.5 " \
            "group-data-[orientation=vertical]/tabs:after:inset-y-0 " \
            "group-data-[orientation=vertical]/tabs:after:-right-1 " \
            "group-data-[orientation=vertical]/tabs:after:w-0.5 " \
            "group-data-[variant=line]/tabs-list:data-[state=active]:after:opacity-100"
          }
        end

        attr_reader :value

        def initialize(value:, **attributes)
          @value = value.to_s
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            role: "tab",
            "aria-selected" => "false",
            tabindex: "-1",
            "data-state" => "inactive",
            "data-value" => value,
            "data-shadcn--tabs-target" => "trigger",
            "data-action" => "click->shadcn--tabs#select keydown->shadcn--tabs#keydown"
          }.merge(defaults))
        end
      end
    end
  end
end
