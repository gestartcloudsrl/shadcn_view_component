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

      # One of each colour, then the same calendar with `default_color:` — the
      # level FullCalendar puts on an event source. The palette is fixed rather
      # than free-form; the reason is in `Event::COLORS`.
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

      # The cell as a *measure* rather than as a list.
      #
      # One row per day: a date column, then the day's chips scrolling sideways.
      # There is no grid arrangement of this reading any more — a month of crews
      # and job counts is a list of days that happens to be a month.
      #
      # @hidden
      def workload
        render_with_template
      end

      # A day as a timeline: every job at the hour it starts, lanes where they
      # overlap. Windowed to working hours — see the template for why.
      #
      # @hidden
      def hours
        render_with_template
      end

      # A host owning the day view: the cells are links, the agenda is the frame
      # they swap, and what comes back carries what the calendar could not. The
      # model, the route and the frame live in `test/dummy` — a preview can
      # render a calendar but cannot answer its links.
      def with_turbo
        render_with_template
      end

      # The playground for the three server-drawn views, and one preview for all
      # of them because the options panel already walks between them: `view_url`
      # points back here, so picking Grid, Rows or Hours is a link to this same
      # page in another state. It was two previews while the toolbar had a
      # control per view.
      #
      # A method rather than a template, so a month of eight hundred events does
      # not become a golden. The fixtures are `workload` and `hours`, which are
      # `@hidden`: they exist to be diffed and audited, not browsed.
      #
      # @param view select [grid, rows, hours]
      # @param most number
      # @param all_day number
      # @param colored toggle
      # @param show_all toggle
      # @param group select [events, assignees]
      # @param shape select [chips, bars]
      # @param from number
      # @param to number
      def density(view: "grid", most: 30, all_day: 1, colored: false, show_all: false,
                  group: "events", shape: "chips", from: 7, to: 23)
        cast = ActiveModel::Type::Boolean.new
        here = lambda do |**changed|
          state = { view:, most:, all_day:, colored: cast.cast(colored),
                    show_all: cast.cast(show_all), group:, shape:, from:, to: }.merge(changed)

          "/lookbook/preview/shadcn/event_calendar/density?#{state.to_query}"
        end
        events = Preview.workload_events(per_day: 0..most.to_i, colored: cast.cast(colored),
                                         durations: view.to_s == "hours", all_day: all_day.to_i)
        common = { month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 20), events:,
                   view_url: ->(name) { here.call(view: name) } }

        if view.to_s == "hours"
          render_component(**common, reading: :hours, window: (from.to_i..to.to_i),
                           shape: shape.to_sym, shape_url: ->(form) { here.call(shape: form) })
        else
          render_component(**common, reading: :workload, group: group.to_sym,
                           arrangement: view.to_s == "rows" ? :rows : :auto,
                           show_all: cast.cast(show_all), show_all_url: ->(all) { here.call(show_all: all) },
                           group_url: ->(cut) { here.call(group: cut) })
        end
      end

      # A roster of six over a month of work, seeded so the gallery shows
      # the same month twice. Counts run from nothing to past the ramp's
      # ceiling, so both ends of the scale are on the page.
      # `all_day:` is how many day-long facts a day may hold. They are the ones
      # with no hour to be placed at — a depot shut, a van off the road — which
      # is the whole point of the case: the grid puts them in its top lanes, a
      # row leads with them, and the hours axis gives them its full width
      # because there is no moment to point at.
      def self.workload_events(month: Date.new(2026, 8, 1), per_day: 0..30, crew: 1..5,
                               seed: 7, colored: false, durations: false, all_day: 0)
        random = Random.new(seed)
        roster = [ "Ada Lovelace", "Grace Hopper", "Alan Turing",
                   "Katherine Johnson", "Linus Pauling", "Marie Curie" ]
        clients = [ "Acme Foods", "Northwind", "Bellini SpA", "Orsini & Co",
                    "Vega Logistics", "Delta Clinic", "Fabbri Srl", "Kite Studio" ]
        # One hue per client, in the palette's fixed order — and the clients past
        # the fifth stay uncategorised rather than starting the list again. A
        # cycled hue says two clients are the same thing, which is the one lie a
        # categorical palette must not tell.
        hues = Shadcn::EventCalendar::Event::COLORS - [ :default ]

        closures = [ "Depot closed", "Stock take", "Van off the road", "Training day" ]

        (month.beginning_of_month..month.end_of_month).flat_map do |day|
          on_shift = roster.sample(random.rand(2..6), random: random)
          # Nothing is drawn at all when the knob is off, rather than drawing
          # zero of them: `rand` consumes from the seeded sequence whether or
          # not the answer is used, so asking and discarding would move every
          # timed event in the month and every fixture with it. With the knob
          # on it is a different month, which is the point.
          all_day_here = Array.new(all_day.to_i.zero? ? 0 : random.rand(0..all_day.to_i)) do
            { title: closures[random.rand(closures.size)],
              starts_at: day, all_day: true,
              assignees: on_shift.sample(random.rand(crew), random: random) }
          end

          all_day_here + Array.new(random.rand(per_day)) do |index|
            client = clients[random.rand(clients.size)]
            starts_at = Time.zone.local(day.year, day.month, day.day,
                                        random.rand(7..18), random.rand(0..59))

            {
              title: client,
              color: (hues[clients.index(client)] if colored),
              starts_at:,
              ends_at: (starts_at + random.rand(1..8) * 30.minutes if durations),
              assignees: on_shift.sample(random.rand(crew), random: random)
            }
          end
        end
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
