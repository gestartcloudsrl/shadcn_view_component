# frozen_string_literal: true

module Shadcn
  module Chart
    module Table
      # The chart's numbers, as a table only a screen reader sees.
      #
      # **Ours.** `chart.tsx` has nothing like it — upstream's answer is
      # recharts' `accessibilityLayer`, which makes the chart arrow-navigable
      # and announces a category at a time.
      #
      # A table is what this port reaches for instead, because a table is
      # already a table: a screen reader enters it in table mode, moves by row
      # and by column, and rereads the column header on demand. What it
      # replaces is one long sentence — *"January: Desktop 186, Mobile 80;
      # February: …"* — which cannot be navigated, cannot be reread in pieces,
      # and by the time a year of months is in it is not a sentence anyone
      # listens to.
      #
      # It is rendered by the shape rather than by the container, so that a
      # shape rendered on its own is still complete, and so that the graphic
      # and its table can never disagree about who carries the data — the same
      # object emits both.
      #
      # Not `Shadcn::Table`, despite the name it shadows inside this module:
      # that family's classes are all visual — borders, padding, hover — and
      # every one of them would be dead CSS on an element no one sees.
      class Component < ApplicationViewComponent
        default_tag :table
        slot_name :"chart-table"

        style do
          base { "sr-only" }
        end

        attr_reader :caption, :columns, :rows

        # `rows` is one array per row: the row's own header, then a cell per
        # column.
        def initialize(caption: nil, columns: [], rows: [], **attributes)
          @caption = caption
          @columns = columns
          @rows = rows
          super(**attributes)
        end

        def call
          render_element(body: safe_join([ heading, head, body ].compact))
        end

        private

        # Not an endless method with a trailing `if`: that reads as *define
        # this method only when the condition holds*, and the condition is
        # evaluated once, against the class.
        def heading
          tag.caption(caption) if caption.present?
        end

        # The corner cell is a `<td>` and not an empty `<th>`: it heads
        # nothing, and a header cell with no text is a header a screen reader
        # still announces.
        def head
          tag.thead(tag.tr(safe_join([ tag.td, *columns.map { |column| tag.th(column, scope: "col") } ])))
        end

        def body
          tag.tbody(safe_join(rows.map do |header, *cells|
            tag.tr(safe_join([ tag.th(header, scope: "row"), *cells.map { |cell| tag.td(cell) } ]))
          end))
        end
      end
    end
  end
end
