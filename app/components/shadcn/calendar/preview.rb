# frozen_string_literal: true

module Shadcn
  module Calendar
    class Preview < ApplicationViewComponentPreview
      # Upstream's own first example, minus the border it wraps it in: a single
      # month with today selected.
      def default
        render_with_template
      end

      # Upstream's "Month and Year Selector".
      def dropdown_caption
        render_with_template
      end

      # Upstream's "Range Calendar".
      def range
        render_with_template
      end

      # Upstream's "Presets".
      def presets
        render_with_template
      end

      # Upstream's "Date and Time Picker".
      def date_and_time
        render_with_template
      end

      # Upstream's "Booked dates".
      def booked
        render_with_template
      end

      # Upstream's "Custom Cell Size".
      def custom_cell_size
        render_with_template
      end

      # Upstream's "Week Numbers".
      def week_numbers
        render_with_template
      end

      # The hidden inputs a Rails form posts.
      def in_a_form
        render_with_template
      end

      # The month is an argument here so a month can be asked for by URL. That
      # is what `spec/system/calendar_spec.rb` compares the browser's own render
      # against: the grid exists twice — in `Calendar::Month` and in the
      # controller — and the only thing that keeps the two honest is asking the
      # server what it would have drawn.
      #
      # @param month text
      def month(month: "2026-09-01")
        render_component(month: Date.parse(month), class: "rounded-md border shadow-sm")
      end
    end
  end
end
