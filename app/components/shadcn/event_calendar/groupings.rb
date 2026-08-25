# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # Which way a reading cuts a day: by the people on it, or by the jobs.
    #
    # Shared by the workload reading and the daily one because they ask the same
    # question of the same data and only draw the answer differently — workload
    # cuts a cell's chips, daily cuts its axis into a row per operator. The menu
    # is one menu, so the two cannot drift apart in what they call things.
    module Groupings
      GROUPINGS = %i[assignees events].freeze

      def self.included(base) = base.attr_reader(:group, :group_url)

      # @param group [Symbol] `:events` — a chip per intervention, which is what
      #   a day's work actually is — or `:assignees`, cut by who is on it.
      # @param group_url [#call, nil] given a grouping, the URL of that state.
      #   Present, the menu is links; absent, it dispatches.
      def initialize(group: :events, group_url: nil, **attributes)
        @group = GROUPINGS.include?(group&.to_sym) ? group.to_sym : :events
        @group_url = group_url
        super(**attributes)
      end

      def by_assignee? = group == :assignees

      private

      def grouping_label = shadcn_t("event_calendar.group.#{group}")

      def grouping_items
        safe_join([
          render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.group.label") },
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::RadioGroup::Component.new) do
            safe_join(GROUPINGS.map { |name| grouping_item(name) })
          end
        ])
      end

      def grouping_item(name)
        href = group_url&.call(name)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: name == group,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#regroup" })
        )) { shadcn_t("event_calendar.group.#{name}") }
      end
    end
  end
end
