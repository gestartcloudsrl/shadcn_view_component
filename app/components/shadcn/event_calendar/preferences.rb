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
    # from the things a host decides, `shapes:`, `views:` and `agenda:`; the
    # rest is fixed.
    class Preferences
      # The form order, and the key order of every set.
      QUESTIONS = %i[period view showing group shape max_chips].freeze

      PERIODS = %i[monthly weekly daily].freeze

      # The values each question takes for a period, first one the default.
      VIEWS = { monthly: %i[grid rows hours], weekly: %i[rows hours] }.freeze
      SHOWING = %i[both axis].freeze
      GROUPS = %i[events assignees].freeze
      # How many chips a capped cell shows before its "+N": any whole number in
      # this range, or `:all`, the toolbar's "Show all" kept for next time.
      # Public so a host checking the limit in its own URLs reads the same
      # numbers as the form.
      MAX_CHIPS_RANGE = (1..99).freeze

      # Questions answered with a number the person types rather than one of a
      # list. `#sets` cannot enumerate them; `#normalize` checks them on their
      # own, and the `:local` URL map carries them as a template.
      FREE = %i[max_chips].freeze

      # The context tokens a question applies in. A context is `[period,
      # "period:second"]`, where `second` is the view, or what a day is showing.
      # `nil` is "always".
      APPLIES = {
        period: nil,
        view: %w[monthly weekly],
        showing: %w[daily],
        group: %w[monthly:grid monthly:rows weekly:rows daily],
        shape: %w[monthly:hours weekly:hours daily:both daily:axis],
        max_chips: %w[monthly:grid monthly:rows weekly:rows daily:rows]
      }.freeze

      # The `view` options carry tokens of their own: a grid only exists in a
      # month.
      VIEW_APPLIES = { grid: %w[monthly], rows: %w[monthly weekly], hours: %w[monthly weekly] }.freeze

      ALWAYS = %w[always].freeze

      attr_reader :shapes, :views

      # @param shapes [Array<Symbol>] the shapes the host offers; the question
      #   is only asked when there is more than one
      # @param agenda [Boolean] whether a day may be shown as a list
      # @param views [Hash{Symbol => Array<Symbol>}] the views each period
      #   offers, as `Component.views_by_period` spells them: `:grid`, `:rows`
      #   and `:hours` for a month or a week, `:rows` and `:hours` for a day.
      #   A period with one second answer is not asked it and its sets carry
      #   none, as a single shape is not asked; one with none is not a period.
      def initialize(shapes:, agenda:, views: Component::DEFAULT_VIEWS)
        @shapes = shapes.to_a.map(&:to_sym)
        @agenda = !!agenda
        @views = views.to_h { |period, list| [ period.to_sym, Array(list).map(&:to_sym) ] }
      end

      # The periods offered: those with a view to draw them in.
      def periods = PERIODS.select { |period| seconds(period).any? }
      # One set per valid answer to the listed questions, keys in `QUESTIONS`
      # order and only those that apply to it. The `FREE` questions are left
      # out: `#asks?` says which sets take one.
      def sets
        @sets ||= periods.flat_map do |period|
          seconds(period).flat_map do |second|
            context = context(period, second)
            asked = QUESTIONS.select { |question| applies?(question, context) } - FREE
            combine(asked, period, second)
          end
        end
      end

      # Whether a set — one of `#sets`, or a whole one — is asked `question`.
      def asks?(question, set)
        # A period offered in one view has none in its set: it is that one.
        second = (set[:period] == :daily ? set[:showing] : set[:view]) || only_view(set[:period])
        applies?(question, context(set[:period], second))
      end

      # `set` with `question` answered `value`, keys back in `QUESTIONS` order,
      # which is the order `.key` spells and the form submits.
      def answer(set, question, value)
        QUESTIONS.each_with_object({}) do |name, answered|
          if name == question
            answered[name] = value
          elsif set.key?(name)
            answered[name] = set[name]
          end
        end
      end

      # What a reading is drawing, as a complete set: keys that do not apply are
      # dropped, listed ones that do and are missing or unknown take their
      # default. `nil` when the period or view is not a real one, or when a
      # chip limit is given and is neither "all" nor a whole number in
      # `MAX_CHIPS_RANGE` — a typed number is checked, not quietly replaced.
      # A limit that is not given at all is the reading's default.
      def normalize(given)
        given = given.to_h.transform_keys(&:to_sym)
        period = given[:period]&.to_sym
        return unless periods.include?(period)

        second = (period == :daily ? given[:showing] : given[:view])&.to_sym || only_view(period)
        return unless seconds(period).include?(second)

        context = context(period, second)
        set = QUESTIONS.select { |question| applies?(question, context) }.to_h do |question|
          value = question == :period ? period : given[question]
          [ question, value_for(question, period, value, second) ]
        end
        set unless set.key?(:max_chips) && set[:max_chips].nil?
      end

      # "all", or a whole number in `MAX_CHIPS_RANGE`, from a form's string or a
      # host's stored value; `nil` for anything else, an empty string included.
      def self.chip_limit(value)
        return :all if value.to_s == "all"

        number = value.is_a?(Integer) ? value : Integer(value.to_s, 10, exception: false)
        number if MAX_CHIPS_RANGE.cover?(number)
      end

      # The context tokens a field — or, given a value, one of its options — is
      # shown in. `["always"]` for the period; none for a question that is not
      # being asked at all.
      def when(question, value = nil)
        return VIEW_APPLIES.fetch(value.to_sym) & asked_views if question == :view && value
        return ALWAYS.dup if APPLIES.fetch(question).nil?
        return [] if question == :shape && shapes.size <= 1
        return asked_views if question == :view
        if question == :showing
          return seconds(:daily).size > 1 ? APPLIES.fetch(:showing).dup : []
        end

        APPLIES.fetch(question).dup
      end

      # The view a period is drawn in when it offers only one, which is why it
      # is not asked — for a day, what it shows; `nil` when there is a choice,
      # or none.
      def only_view(period)
        choices = seconds(period)
        choices.first if choices.size == 1
      end

      # The same string on both sides: the controller rebuilds it from
      # `FormData`, so the order and the spelling here are the contract.
      def self.key(set)
        set.map { |question, value| "preferences[#{question}]=#{value}" }.join("&")
      end

      private

      # What follows the period: the view, or for a day what it shows.
      # A day's row first, then the timeline's ways of showing.
      def seconds(period)
        offered = views.fetch(period, [])
        return VIEWS.fetch(period) & offered unless period == :daily

        rows = offered.include?(:rows) ? %i[rows] : []
        hours = offered.include?(:hours) ? SHOWING + (@agenda ? %i[agenda] : []) : []
        rows + hours
      end

      # The periods whose view is a question: those with more than one.
      def asked_views = APPLIES.fetch(:view).select { |period| seconds(period.to_sym).size > 1 }

      def context(period, second) = [ period.to_s, "#{period}:#{second}" ]

      def applies?(question, context)
        return true if question == :period
        return false if question == :shape && shapes.size <= 1
        return seconds(context.first.to_sym).size > 1 if question == :view && context.first != "daily"
        return seconds(:daily).size > 1 if question == :showing && context.first == "daily"

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
        end
      end

      def value_for(question, period, value, second)
        return second if question == :view || question == :showing
        return period if question == :period
        if question == :max_chips
          return value.nil? ? Workload::Component::MAX_CHIPS : self.class.chip_limit(value)
        end

        value = value&.to_sym
        options(question).include?(value) ? value : options(question).first
      end
    end
  end
end
