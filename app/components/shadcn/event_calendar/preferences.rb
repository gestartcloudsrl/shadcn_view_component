# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # Every view a person can prefer, named once.
    #
    # The calendar asks up to six questions and which of them it asks depends on
    # the answers to the first two: a month drawn as a grid has no timeline to
    # shape, a day has no view. This is that dependency written down as data, so
    # the form that asks, the server that checks the answer and the browser that
    # shows and hides fields all read one table instead of three copies of it.
    #
    # A plain object like `Schedule`, because it renders nothing. It is built
    # from the two things a host decides, `shapes:` and `agenda:`; the rest is
    # fixed.
    class Preferences
      # The form order, and the key order of every set.
      QUESTIONS = %i[period view showing group shape max_chips].freeze

      PERIODS = %i[monthly weekly daily].freeze

      # The values each question takes for a period, first one the default.
      VIEWS = { monthly: %i[grid rows hours], weekly: %i[rows hours] }.freeze
      SHOWING = %i[both axis].freeze
      GROUPS = %i[events assignees].freeze
      # How many chips a capped cell shows before its "+N", or every one. The
      # first is the reading's own default (`Workload::Component::MAX_CHIPS`).
      # `:all` is the toolbar's "Show all" kept for next time.
      MAX_CHIPS = [ 3, 5, :all ].freeze

      # The context tokens a question applies in. A context is `[period,
      # "period:second"]`, where `second` is the view, or what a day is showing.
      # `nil` is "always".
      APPLIES = {
        period: nil,
        view: %w[monthly weekly],
        showing: %w[daily],
        group: %w[monthly:grid monthly:rows weekly:rows daily],
        shape: %w[monthly:hours weekly:hours daily:both daily:axis],
        max_chips: %w[monthly:grid monthly:rows weekly:rows]
      }.freeze

      # The `view` options carry tokens of their own: a grid only exists in a
      # month.
      VIEW_APPLIES = { grid: %w[monthly], rows: %w[monthly weekly], hours: %w[monthly weekly] }.freeze

      ALWAYS = %w[always].freeze

      attr_reader :shapes

      # @param shapes [Array<Symbol>] the shapes the host offers; the question
      #   is only asked when there is more than one
      # @param agenda [Boolean] whether a day may be shown as a list
      def initialize(shapes:, agenda:)
        @shapes = shapes.to_a.map(&:to_sym)
        @agenda = !!agenda
      end

      # One set per valid answer, keys in `QUESTIONS` order and only those that
      # apply to it.
      def sets
        @sets ||= PERIODS.flat_map do |period|
          seconds(period).flat_map do |second|
            context = context(period, second)
            asked = QUESTIONS.select { |question| applies?(question, context) }
            combine(asked, period, second)
          end
        end
      end

      # What a reading is drawing, as one of `#sets`: keys that do not apply are
      # dropped, ones that do and are missing or unknown take their default.
      # `nil` when the period or view is not a real one.
      def normalize(given)
        given = given.to_h.transform_keys(&:to_sym)
        period = given[:period]&.to_sym
        return unless PERIODS.include?(period)

        second = period == :daily ? given[:showing]&.to_sym : given[:view]&.to_sym
        return unless seconds(period).include?(second)

        context = context(period, second)
        QUESTIONS.select { |question| applies?(question, context) }.to_h do |question|
          value = question == :period ? period : given[question]
          [ question, value_for(question, period, value, second) ]
        end
      end

      # The context tokens a field — or, given a value, one of its options — is
      # shown in. `["always"]` for the period; none for a question that is not
      # being asked at all.
      def when(question, value = nil)
        return VIEW_APPLIES.fetch(value.to_sym).dup if question == :view && value
        return ALWAYS.dup if APPLIES.fetch(question).nil?
        return [] if question == :shape && shapes.size <= 1

        APPLIES.fetch(question).dup
      end

      # The same string on both sides: the controller rebuilds it from
      # `FormData`, so the order and the spelling here are the contract.
      def self.key(set)
        set.map { |question, value| "preferences[#{question}]=#{value}" }.join("&")
      end

      private

      # What follows the period: the view, or for a day what it shows.
      def seconds(period)
        return SHOWING + (@agenda ? %i[agenda] : []) if period == :daily

        VIEWS.fetch(period)
      end

      def context(period, second) = [ period.to_s, "#{period}:#{second}" ]

      def applies?(question, context)
        return true if question == :period
        return false if question == :shape && shapes.size <= 1

        (APPLIES.fetch(question) & context).any?
      end

      # The answers to the questions the period and its second one leave open,
      # as complete sets in question order.
      def combine(asked, period, second)
        fixed = { period: period, (period == :daily ? :showing : :view) => second }
        free = asked - fixed.keys
        lists = free.map { |question| options(question) }

        (lists.empty? ? [ [] ] : lists.first.product(*lists.drop(1))).map do |values|
          answers = fixed.merge(free.zip(values).to_h)
          asked.to_h { |question| [ question, answers.fetch(question) ] }
        end
      end

      def options(question)
        case question
        when :group then GROUPS
        when :shape then shapes
        when :max_chips then MAX_CHIPS
        end
      end

      def value_for(question, period, value, second)
        return second if question == :view || question == :showing
        return period if question == :period

        value = question == :max_chips ? chip_limit(value) : value&.to_sym
        options(question).include?(value) ? value : options(question).first
      end

      # "all" or a number, as a form or a host's stored set spells it.
      def chip_limit(value)
        value.to_s == "all" ? :all : Integer(value.to_s, exception: false)
      end
    end
  end
end
