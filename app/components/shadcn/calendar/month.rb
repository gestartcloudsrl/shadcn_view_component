# frozen_string_literal: true

module Shadcn
  module Calendar
    # One month, as a grid of weeks.
    #
    # This is the part `react-day-picker` mostly *is* — `helpers/getDates.js`,
    # `helpers/getWeeks.js` and the 576 lines of `classes/DateLib.js` that wrap
    # `date-fns` — and it is the part Ruby already has. `Date` does the
    # arithmetic and `I18n` does the names, so nothing here needs a dependency.
    #
    # A plain object rather than a component: it renders nothing, and being
    # able to assert on a grid without a browser is worth more than the
    # symmetry.
    class Month
      DAYS_IN_WEEK = 7

      attr_reader :date, :week_starts_on, :fixed_weeks

      # `week_starts_on` is a weekday number, 0 for Sunday, matching
      # `Date#wday` — and defaulting to the host application's own
      # `Date.beginning_of_week` rather than to a constant, because that is the
      # setting a Rails app has already made. Upstream takes it from the locale.
      def initialize(date = Date.current, week_starts_on: nil, fixed_weeks: false)
        @date = date.to_date
        @week_starts_on = week_starts_on || Date::DAYNAMES.index(Date.beginning_of_week.to_s.capitalize)
        @fixed_weeks = fixed_weeks
      end

      def first = date.beginning_of_month
      def last = date.end_of_month

      # Every date the grid holds, including the days either side that fill the
      # first and last weeks out. Six rows when `fixed_weeks` is asked for, so a
      # calendar that is navigated does not change height under the pointer —
      # upstream's `fixedWeeks`, and the reason it exists.
      def weeks
        start = shift_back(first)
        rows = fixed_weeks ? 6 : ((shift_forward(last) - start + 1) / DAYS_IN_WEEK)

        Array.new(rows) do |row|
          Array.new(DAYS_IN_WEEK) { |column| start + (row * DAYS_IN_WEEK) + column }
        end
      end

      def days = weeks.flatten

      def outside?(day) = day.month != date.month

      # ISO-8601, which is `Date#cweek`. Upstream's week number follows the
      # locale and can differ — the US counts from a different week — and this
      # port does not reproduce that; see features/calendar.md.
      def number_of(week) = week.first.cweek

      def previous = self.class.new(first.prev_month, **options)
      def next = self.class.new(first.next_month, **options)

      # Sunday-first `Date::DAYNAMES`, rotated to whichever day the week starts
      # on. The names themselves come from `I18n` at render time, not from here.
      def weekday_numbers
        Array.new(DAYS_IN_WEEK) { |offset| (week_starts_on + offset) % DAYS_IN_WEEK }
      end

      private

      def options = { week_starts_on:, fixed_weeks: }

      def shift_back(day) = day - ((day.wday - week_starts_on) % DAYS_IN_WEEK)

      def shift_forward(day) = day + ((week_starts_on - 1 - day.wday) % DAYS_IN_WEEK)
    end
  end
end
