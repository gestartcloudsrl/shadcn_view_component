# frozen_string_literal: true

module Shadcn
  module EventCalendar
    class Preview < ApplicationViewComponentPreview
      # A month with something in it — the arrangement FullCalendar's own demo
      # uses, because it is the one that exercises the awkward cases: a bar that
      # crosses a week boundary, two events on the same day at different times,
      # and a day with more than there is room for.
      def default
        render_with_template
      end

      # One of each colour. The palette is fixed rather than free-form; the
      # reason is in `Event::COLORS`.
      def colors
        render_with_template
      end

      # More events on one day than the cell has lanes, at two settings of
      # `max_events`. What a cell cannot show, the agenda underneath does — on
      # every screen, which is why there is no "+2" popover to open.
      def busy
        render_with_template
      end

      # A month with nothing in it, which is what a host sees first.
      def empty
        render_with_template
      end

      # The month is an argument here so a month can be asked for by URL — the
      # same reason `Calendar::Preview#month` takes one. The grid and the lane
      # packing exist twice, in `Schedule` and in the controller, and the only
      # thing that keeps the two honest is asking the server what it would have
      # drawn.
      #
      # @param month text
      def month(month: "2026-09-01")
        render_component(month: Date.parse(month), events: Preview.sample_events)
      end

      # Shared by the previews above and by `spec/system/event_calendar_spec.rb`,
      # so that what the browser is driven through is what the gallery shows.
      def self.sample_events
        [
          { title: "All Day Event", starts_at: Date.new(2026, 8, 1) },
          { title: "Long Event", starts_at: Date.new(2026, 8, 7), ends_at: Date.new(2026, 8, 9), color: :blue },
          { title: "Team Sync", starts_at: Time.zone.local(2026, 8, 12, 9, 0), color: :rose },
          { title: "Repeating Event", starts_at: Time.zone.local(2026, 8, 16, 16, 0), color: :violet },
          { title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21), color: :violet },
          { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9, 0), color: :rose },
          { title: "Meeting", starts_at: Time.zone.local(2026, 8, 20, 10, 30),
            ends_at: Time.zone.local(2026, 8, 20, 11, 30), color: :green },
          { title: "Lunch", starts_at: Time.zone.local(2026, 8, 20, 12, 0) },
          { title: "Birthday Party", starts_at: Time.zone.local(2026, 8, 21, 7, 0), color: :amber },
          { title: "Release", starts_at: Time.zone.local(2026, 8, 28, 15, 0), color: :green }
        ]
      end
    end
  end
end
