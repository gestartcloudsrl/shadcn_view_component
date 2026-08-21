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
      def workload
        render_with_template
      end

      # A day as a timeline: every job at the hour it starts, lanes where they
      # overlap. Windowed to working hours — see the template for why.
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

      # The same reading with the knobs on. `colored` gives each event's subject
      # its own hue, which is what makes the chips worth colouring at all — a
      # colour that means nothing is noise.
      #
      # A method rather than a template, so a month of eight hundred events does
      # not become a golden. The shape it exercises is the shipped one above.
      #
      # `show_all` is server state now, not a class toggle: a cell renders what
      # it shows. The toggle in the toolbar is a link back to this preview in
      # the other state, which is what a host would wire it to.
      #
      # `arrangement` is the toolbar's Rows toggle, and it is a URL here for
      # the same reason the other two are: press › and the server draws the
      # next month, which would not otherwise know what you had chosen. Widen
      # the window past `lg` to see it do anything.
      #
      # @param most number
      # @param colored toggle
      # @param show_all toggle
      # @param group select [events, assignees]
      # @param arrangement select [auto, rows]
      def workload_density(most: 30, colored: false, show_all: false, group: "events",
                           arrangement: "auto")
        cast = ActiveModel::Type::Boolean.new
        here = lambda do |all: cast.cast(show_all), cut: group, laid: arrangement|
          "/lookbook/preview/shadcn/event_calendar/workload_density" \
            "?most=#{most}&colored=#{cast.cast(colored)}&show_all=#{all}&group=#{cut}" \
            "&arrangement=#{laid}"
        end
        # One callback for the whole panel: two of the views are this preview at
        # a different arrangement, the third is the other one.
        view_here = lambda do |name|
          next here.call(laid: name == :rows ? :rows : :auto) unless name == :hours

          "/lookbook/preview/shadcn/event_calendar/hours_density" \
            "?most=#{most}&colored=#{cast.cast(colored)}&from=7&to=23"
        end

        render_component(month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 20),
                         reading: :workload, group: group.to_sym,
                         show_all: cast.cast(show_all), show_all_url: ->(all) { here.call(all:) },
                         group_url: ->(cut) { here.call(cut:) },
                         arrangement: arrangement.to_sym, view_url: view_here,
                         events: Preview.workload_events(per_day: 0..most.to_i,
                                                         colored: cast.cast(colored)))
      end

      # SPIKE — the hour track: a day as a proportional 24-hour axis rather than
      # a strip of chips, so the same x is the same hour on every row.
      #
      # Throwaway. It exists to answer whether that reads at this density, and
      # `durations: true` is part of the question — the sample events had no
      # `ends_at` at all, so on a time axis every one of them was an instant and
      # there was no duration to see.
      #
      # `as` is the question this spike is really asking: a bar is as wide as
      # its duration and says nothing else, a chip says who and for whom and is
      # as wide as that takes. They cannot both be packed the same way — see
      # `Schedule#track_on`'s `floor:`.
      #
      # @param most number
      # @param colored toggle
      # @param from number
      # @param to number
      # @param as select [chips, bars]
      def hours_density(most: 8, colored: true, from: 0, to: 24, as: "chips")
        cast = ActiveModel::Type::Boolean.new
        # `shape_here` first: a lambda body resolves a name at call time, but
        # Ruby decides whether it *is* a local when it parses the assignment —
        # referring to it from a lambda defined above made it a method call.
        shape_here = lambda do |form|
          "/lookbook/preview/shadcn/event_calendar/hours_density" \
            "?most=#{most}&colored=#{cast.cast(colored)}&from=#{from}&to=#{to}&as=#{form}"
        end
        view_here = lambda do |name|
          next shape_here.call(as) if name == :hours

          "/lookbook/preview/shadcn/event_calendar/workload_density" \
            "?most=#{most}&colored=#{cast.cast(colored)}&arrangement=#{name == :rows ? 'rows' : 'auto'}"
        end

        render_component(month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 20),
                         reading: :hours,
                         window: (from.to_i..to.to_i), shape: as.to_sym, shape_url: shape_here,
                         view_url: view_here,
                         events: Preview.workload_events(per_day: 0..most.to_i,
                                                         colored: cast.cast(colored),
                                                         durations: true))
      end

      # A roster of six over a month of work, seeded so the gallery shows
      # the same month twice. Counts run from nothing to past the ramp's
      # ceiling, so both ends of the scale are on the page.
      def self.workload_events(month: Date.new(2026, 8, 1), per_day: 0..30, crew: 1..5,
                               seed: 7, colored: false, durations: false)
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

        (month.beginning_of_month..month.end_of_month).flat_map do |day|
          on_shift = roster.sample(random.rand(2..6), random: random)

          Array.new(random.rand(per_day)) do |index|
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
