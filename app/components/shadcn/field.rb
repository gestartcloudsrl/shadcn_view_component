# frozen_string_literal: true

module Shadcn
  # The parts of the Field family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Field
    extend Parts

    part :content, slot: "field-content",
                   classes: "group/field-content flex flex-1 flex-col gap-1.5 leading-snug"

    part :description, tag: :p, slot: "field-description",
                       classes: "text-sm leading-normal font-normal text-muted-foreground " \
                                "group-has-[[data-orientation=horizontal]]/field:text-balance " \
                                "last:mt-0 nth-last-2:-mt-1 [[data-variant=legend]+&]:-mt-1.5 " \
                                "[&>a]:underline [&>a]:underline-offset-4 " \
                                "[&>a:hover]:text-primary"

    part :group, slot: "field-group",
                 classes: "group/field-group @container/field-group flex w-full flex-col gap-7 " \
                          "data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4"

    part :label, tag: :label, slot: "field-label",
                 classes: "flex items-center gap-2 text-sm leading-none font-medium select-none " \
                          "group-data-[disabled=true]:pointer-events-none " \
                          "group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed " \
                          "peer-disabled:opacity-50 group/field-label peer/field-label flex w-fit " \
                          "gap-2 leading-snug group-data-[disabled=true]/field:opacity-50 " \
                          "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col " \
                          "has-[>[data-slot=field]]:rounded-md has-[>[data-slot=field]]:border " \
                          "[&>*]:data-[slot=field]:p-4 has-data-[state=checked]:border-primary " \
                          "has-data-[state=checked]:bg-primary/5 " \
                          "dark:has-data-[state=checked]:bg-primary/10"

    part :set, tag: :fieldset, slot: "field-set",
               classes: "flex flex-col gap-6 has-[>[data-slot=checkbox-group]]:gap-3 " \
                        "has-[>[data-slot=radio-group]]:gap-3"

    part :title, slot: "field-label",
                 classes: "flex w-fit items-center gap-2 text-sm leading-snug font-medium " \
                          "group-data-[disabled=true]/field:opacity-50"
  end
end
