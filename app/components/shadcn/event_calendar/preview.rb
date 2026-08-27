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

      # Moving an event. `Space` on a row of the agenda takes it, the arrow keys
      # choose a day and `Space` puts it down; a pointer drags the grip on a
      # bar. The calendar dispatches and stops there — saving is the host's, and
      # this preview has no host, so a move survives until the page reloads.
      def movable
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

      # @hidden
      def hours_bars
        render_with_template
      end

      # @hidden
      def workload_by_assignee
        render_with_template
      end

      # The day in a Sheet, at its default month — the same template `density`
      # renders when its `turbo` knob asks for a panel, with the locals left
      # out so the defaults stand.
      #
      # `@hidden` because `density` is the page to browse; this exists to be
      # *driven*. It has to exist, though, and that is not obvious: both
      # `snapshot_spec` and `accessibility_spec` derive their lists from the
      # template files on disk, and the second visits `family/name` as a
      # preview — so a template with no method of the same name has no URL, and
      # the axe example 404s rather than saying what is wrong.
      #
      # @hidden
      def panel
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
      # Two questions, in the order the options panel asks them: `period` is
      # what you are looking at, `view` is how the month is drawn. They were one
      # knob — `view select [grid, rows, hours, daily]` — and `daily` is not a
      # view, it is a period; `monthly` had no spelling at all, being merely the
      # absence of `daily`.
      #
      # The component keeps them apart too (`PERIODS` and `VIEWS`, two menus
      # with two labels) and joins them only in `view_url:`, which is one
      # callback on purpose — see the note above `VIEWS`. So the mapping lives
      # here, in the host, which is where a host's URL scheme belongs.
      #
      # Listed in the order of the signature, which they were not: Lookbook
      # draws the controls in `@param` order, and `showing` sat third, between
      # `view` and `most`, a long way from the daily knobs it belongs to.
      #
      # @param month text
      # @param period select [monthly, daily]
      # @param view select [grid, rows, hours]
      # @param most number
      # @param all_day number
      # @param spanning number
      # @param colored toggle
      # @param show_all toggle
      # @param group select [events, assignees]
      # @param shape select [chips, bars]
      # @param showing select [both, axis, agenda]
      # @param from number
      # @param to number
      # @param turbo select [off, panel, agenda]
      def density(month: "2026-08-01", period: "monthly", view: "grid", most: 30, all_day: 1,
                  spanning: 3, colored: false, show_all: false, group: "events", shape: "chips",
                  showing: "both", from: 7, to: 23, turbo: "off")
        cast = ActiveModel::Type::Boolean.new
        shown = Date.parse(month)
        here = lambda do |**changed|
          state = { month:, period:, view:, most:, all_day:, spanning:, colored: cast.cast(colored),
                    show_all: cast.cast(show_all), group:, shape:, showing:, from:, to:,
                    turbo: }.merge(changed)

          "/lookbook/preview/shadcn/event_calendar/density?#{state.to_query}"
        end
        # The month is a URL here because a server-drawn reading has no other
        # way to change one: its cells hold crews and clients the payload does
        # not carry, so the controller announces the ask and leaves the DOM
        # alone. A host wires `month_url:` to its own route; this wires it to
        # the same preview in another month.
        # With `turbo` on the events come from the dummy's own table instead of
        # the generator, because the whole point is that the day link is
        # answered: a cell drawn from an invented event would open a day page
        # that has never heard of it. The density knobs go inert for the same
        # reason, and the appointments live in August 2026 — walk to another
        # month and the calendar is honestly empty.
        owned = turbo.to_s != "off"
        events =
          if owned
            Appointment.for_calendar
          else
            Preview.workload_events(month: shown, per_day: 0..most.to_i, colored: cast.cast(colored),
                                    durations: view.to_s == "hours", all_day: all_day.to_i,
                                    spanning: spanning.to_i)
          end
        # One callback in, two parameters out. `view_url` is handed `:daily` for
        # the period and one of `:grid`/`:rows`/`:hours` for the view, so
        # picking a view also says the period is monthly — which is what makes
        # `monthly` expressible rather than implied.
        daily = period.to_s == "daily"
        common = { month: shown, events:,
                   view_url: lambda { |name|
                     case name.to_s
                     when "daily", "monthly" then here.call(period: name)
                     else here.call(period: "monthly", view: name)
                     end
                   },
                   month_url: ->(date) { here.call(month: date.iso8601) } }

        args =
          if daily
            common.merge(reading: :daily, selected: shown,
                         window: (from.to_i..to.to_i), shape: shape.to_sym,
                         showing: showing.to_sym, group: group.to_sym,
                         shape_url: ->(form) { here.call(shape: form) },
                         showing_url: ->(half) { here.call(showing: half) },
                         group_url: ->(cut) { here.call(group: cut) })
          elsif view.to_s == "hours"
            common.merge(reading: :hours, window: (from.to_i..to.to_i),
                         shape: shape.to_sym, shape_url: ->(form) { here.call(shape: form) })
          else
            common.merge(reading: :workload, group: group.to_sym,
                         arrangement: view.to_s == "rows" ? :rows : :auto,
                         show_all: cast.cast(show_all), show_all_url: ->(all) { here.call(show_all: all) },
                         group_url: ->(cut) { here.call(group: cut) })
          end

        # Two shapes a host can give the day, and they are genuinely different
        # rather than two skins.
        #
        # **panel** — a Sheet that opens over the page, so one click both fills
        # the frame and opens it. A preview method cannot build this: a Sheet's
        # content is a slot and a slot needs a block, so the arguments are
        # assembled here and handed to a template that supplies the markup.
        #
        # **agenda** — the component's own agenda *is* the frame, via
        # `agenda_as:`. No markup, but it sits under six weeks of grid: it
        # updated 335px below the fold and a click read as nothing happening,
        # which is what `autoscroll` is for and what a panel never needs.
        return render_component(**args) unless owned

        if turbo.to_s == "agenda"
          return render_component(**args,
                                  day_url: ->(date) { "/calendar/days/#{date.iso8601}" },
                                  day_attributes: { data: { turbo_frame: "day" } },
                                  agenda_as: :"turbo-frame",
                                  agenda_attributes: { id: "day", autoscroll: true,
                                                       data: { autoscroll_block: "center" } })
        end

        render_with_template(template: "shadcn/event_calendar/previews/panel",
                             locals: { calendar: args })
      end

      # A roster of six over a month of work, seeded so the gallery shows
      # the same month twice. Counts run from nothing to past the ramp's
      # ceiling, so both ends of the scale are on the page.
      # `spanning:` is how many jobs in the month run across several days —
      # half of them all-day, half with a clock, because that pair is where the
      # lane ordering is decided and a fixture of only one kind proves nothing
      # about it.
      #
      # `all_day:` is how many day-long facts a day may hold. They are the ones
      # with no hour to be placed at — a depot shut, a van off the road — which
      # is the whole point of the case: the grid puts them in its top lanes, a
      # row leads with them, and the hours axis gives them its full width
      # because there is no moment to point at.
      def self.workload_events(month: Date.new(2026, 8, 1), per_day: 0..30, crew: 1..5,
                               seed: 7, colored: false, durations: false, all_day: 0, spanning: 0)
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

        days = (month.beginning_of_month..month.end_of_month).to_a
        # Drawn first and from its own generator, so the knob does not disturb
        # the per-day sequence below — the same reason `all_day:` draws nothing
        # when it is off.
        crossing = Array.new(spanning.to_i) do |index|
          span = Random.new(seed + index).rand(2..5)
          from = days[Random.new(seed + index + 100).rand(0..(days.size - span - 1))]

          { title: "#{clients[index % clients.size]} — #{span}-day job",
            color: (hues[index % hues.size] if colored),
            starts_at: index.even? ? from : Time.zone.local(from.year, from.month, from.day, 9),
            ends_at: index.even? ? from + (span - 1) : Time.zone.local(from.year, from.month, from.day, 17) + (span - 1).days,
            all_day: index.even?,
            assignees: roster.first(2) }
        end

        crossing + days.flat_map do |day|
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
