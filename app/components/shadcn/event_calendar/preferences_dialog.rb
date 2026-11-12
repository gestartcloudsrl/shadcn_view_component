# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # The dialog that lets a person choose how the calendar opens, drawn by the
    # server from `Preferences`.
    #
    # It draws **every** question, not just the ones the current view asks. The
    # fields that do not apply are `hidden` and their input `disabled`, and each
    # carries `data-preferences-when` — the context tokens it applies in — so
    # the controller can show and hide them as the answers change without
    # knowing a thing about which question follows which. That is the table
    # `Preferences` owns; this file only prints it.
    #
    # Mixed into the base component and drawn only by the readings that have a
    # panel to put the item in (`#panel?`).
    module PreferencesDialog
      MODES = %i[local host].freeze

      # The words under `event_calendar.*` each question is headed with, and for
      # each of its options. `view` has a second heading, for the week.
      HEADINGS = {
        period: "period.label", view: "view.label", showing: "daily.label",
        group: "group.label", shape: "hours.label", max_chips: "preferences.max_chips"
      }.freeze

      OPTION_KEYS = {
        period: "period.%s", view: "view.%s", showing: "daily.%s",
        group: "group.%s", shape: "hours.%s", max_chips: "preferences.max_chips_%s"
      }.freeze

      # The chip limit's two answers, as its radio group submits them: a number
      # the person types, or every chip. Only one reaches the form —
      # `preferences[max_chips]` is the typed number or "all", never both.
      LIMIT_CHOICES = %w[number all].freeze
      PREFERENCES_LIMIT_INPUT_CLASS = "w-20"

      # In a `:local` URL map, the key of a set whose chip limit is a typed
      # number, and the two numbers the host's `preferences_url:` is called
      # with to find where that number lands in its URL.
      LIMIT_PLACEHOLDER = "#"
      LIMIT_PROBES = [ 23, 45 ].freeze
      PREFERENCES_CONTENT_CLASS = "max-h-[calc(100dvh-2rem)] grid-rows-[auto_minmax(0,1fr)]"
      PREFERENCES_FORM_CLASS = "flex min-h-0 flex-col gap-4"
      # `-m-1 p-1`: a scroller clips what overflows it, and the radios'
      # focus ring is 3px outside them.
      PREFERENCES_BODY_CLASS = "-m-1 flex min-h-0 flex-col gap-4 overflow-y-auto p-1"

      attr_reader :preferences_mode

      private

      def initialize_preferences(preferences, preferences_url, preferences_save_url, restore)
        @preferences_mode = (preferences.to_sym if preferences)
        @preferences_url = preferences_url
        @preferences_save_url = preferences_save_url
        @restore = ActiveModel::Type::Boolean.new.cast(restore) || false
        return if @preferences_mode.nil?

        unless MODES.include?(@preferences_mode)
          raise ArgumentError, "preferences: must be :local, :host or nil, got #{preferences.inspect}"
        end

        if @preferences_mode == :local && preferences_url.nil?
          raise ArgumentError, "EventCalendar(preferences: :local) needs preferences_url:, " \
                               "a callable that returns the URL of a set"
        elsif @preferences_mode == :host && preferences_save_url.nil?
          raise ArgumentError, "EventCalendar(preferences: :host) needs preferences_save_url:, " \
                               "where the form is sent"
        end
      end

      # The panel is where the item lives, and the base reading (`:auto`) has
      # none.
      def panel? = false

      def preferences? = !preferences_mode.nil? && panel?

      def preference_values = {}

      # One per instance, so two calendars on a page do not share an id and a
      # `<label for>` or `aria-labelledby` never reaches into the other's
      # dialog. The `shadcn-<part>-<eight hex>` shape is the gem's convention.
      def preference_id(question, part)
        @preference_hex ||= SecureRandom.hex(4)
        "shadcn-event-calendar-preferences-#{@preference_hex}-#{question}-#{part}"
      end

      def preference_table = @preference_table ||= Preferences.new(shapes:, agenda: @agenda)

      # What the reading is drawing right now, as one of `Preferences#sets`.
      def preference_current
        @preference_current ||= begin
          values = preference_values
          preference_table.normalize(values) || preference_table.normalize(values.merge(showing: :both))
        end
      end

      def preference_attributes
        return {} unless preferences?

        local = preferences_mode == :local
        {
          "data-shadcn--event-calendar-preferences-value" => preferences_mode,
          "data-shadcn--event-calendar-preferences-current-value" => Preferences.key(preference_current),
          "data-shadcn--event-calendar-preferences-storage-value" =>
            "shadcn--event-calendar:preferences:#{attributes[:id] || 'default'}",
          "data-shadcn--event-calendar-preferences-restore-value" => (@restore.to_s if local),
          "data-shadcn--event-calendar-preferences-urls-value" => (preference_urls.to_json if local)
        }.compact
      end

      # Every set's URL, keyed as the controller spells what the form holds.
      # A set that asks the chip limit has one URL for "all" and, for a typed
      # number, a template: the URL cut in two where the number goes.
      def preference_urls
        preference_table.sets.each_with_object({}) do |set, urls|
          unless preference_table.asks?(:max_chips, set)
            urls[Preferences.key(set)] = @preferences_url.call(set)
            next
          end

          all = preference_table.answer(set, :max_chips, :all)
          urls[Preferences.key(all)] = @preferences_url.call(all)
          urls[Preferences.key(preference_table.answer(set, :max_chips, LIMIT_PLACEHOLDER))] = preference_url_template(set)
        end
      end

      # The host's lambda is called with two numbers and the URLs compared:
      # what they share before and after is the template. The same URL twice
      # means the limit never reaches it, which is the host's to decide. A
      # lambda that writes the number some other way — twice, or changed — has
      # no place to put a typed one, and is told so rather than sent somewhere
      # else.
      def preference_url_template(set)
        first, second = LIMIT_PROBES.map { |number| @preferences_url.call(preference_table.answer(set, :max_chips, number)).to_s }
        return first if first == second

        head = first.each_char.zip(second.each_char).take_while { |a, b| a == b }.size
        room = [ first.size, second.size ].min - head
        tail = first.reverse.each_char.zip(second.reverse.each_char).take(room).take_while { |a, b| a == b }.size
        cut = ->(url) { url[head...(url.size - tail)] }

        unless cut.call(first) == LIMIT_PROBES.first.to_s && cut.call(second) == LIMIT_PROBES.last.to_s
          raise ArgumentError, "EventCalendar(preferences: :local): preferences_url: must write max_chips " \
                               "into the URL once, as given, so a typed limit has a place to go"
        end

        [ first[0, head], first[(first.size - tail)..] ]
      end

      # The menu's way in: it sits under the panel's questions.
      def preferences_item
        safe_join([
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::Item::Component.new(
            "data-action": "click->shadcn--event-calendar#openPreferences"
          )) do
            safe_join([ render(Icon::Component.new("user-cog")), shadcn_t("event_calendar.preferences.item") ])
          end
        ])
      end

      def preferences_dialog
        render(Dialog::Component.new("data-shadcn--event-calendar-target": "preferencesDialog")) do |dialog|
          # Six questions are taller than a short window, and a dialog that
          # grows past it puts Save off-screen. The panel stops at the window
          # and the questions scroll between a fixed header and footer — the
          # dialog's own "scrollable content" preview, with the form as the
          # row that gives (`minmax(0,1fr)`, since a grid row will not shrink
          # below its content otherwise).
          dialog.with_dialog_content(class: PREFERENCES_CONTENT_CLASS) do |content|
            content.with_header do |header|
              header.with_title { shadcn_t("event_calendar.preferences.title") }
              header.with_description { shadcn_t("event_calendar.preferences.description") }
            end
            preferences_form
          end
        end
      end

      def preferences_form
        local = preferences_mode == :local
        action = "change->shadcn--event-calendar#refinePreferences"
        action = "submit->shadcn--event-calendar#savePreferences #{action}" if local

        # `:local` never submits the form, so a token would only sit in the DOM.
        form_with(scope: :preferences, url: (local ? "#" : @preferences_save_url),
                  authenticity_token: (false if local),
                  method: (local ? :post : :patch), builder: ShadcnViewComponent::FormBuilder,
                  class: PREFERENCES_FORM_CLASS,
                  data: { "shadcn--event-calendar-target": "preferencesForm", action: }) do |form|
          safe_join([
            tag.div(safe_join(Preferences::QUESTIONS.filter_map { |question| preference_question(form, question) }),
                    "data-slot": "event-calendar-preferences-body", class: PREFERENCES_BODY_CLASS),
            render(Dialog::Footer::Component.new) do
              safe_join([
                render(Dialog::Close::Component.new(class: Button::Component.variant_classes(variant: :outline))) do
                  shadcn_t("event_calendar.preferences.cancel")
                end,
                form.shadcn_submit(shadcn_t("event_calendar.preferences.save"))
              ])
            end
          ])
        end
      end

      # A question is not drawn at all when `Preferences` has no tokens for it
      # (the shape, when only one is offered); drawn but `hidden` when it has
      # tokens that do not include this reading's.
      def preference_question(form, question)
        tokens = preference_table.when(question)
        return if tokens.empty?

        applies = preference_current.key?(question)
        labelled = question == :view ? preference_id(:view, preference_view_heading) : preference_id(question, "label")

        tag.div(
          safe_join([ *preference_headings(form, question), preference_answers(form, question, applies, labelled) ]),
          "data-slot": "event-calendar-preference", class: "grid gap-3",
          "data-preferences-when": tokens.join(" "), hidden: (true unless applies)
        )
      end

      # The view is asked as "Show the month as" or "Show the week as", and both
      # headings are drawn: the controller shows the one that applies.
      def preference_headings(form, question)
        if question == :view
          return [ preference_heading(form, :view, "view.label", "monthly"),
                   preference_heading(form, :view, "view.week_label", "weekly") ]
        end

        [ preference_heading(form, question, HEADINGS.fetch(question), nil) ]
      end

      def preference_heading(form, question, key, period)
        shown = period ? preference_current[:period].to_s == period : true
        id = preference_id(question, period ? (period == "weekly" ? "week" : "month") : "label")

        render(Label::Component.new(id:, "data-preferences-when": period, hidden: (true unless shown))) do
          shadcn_t("event_calendar.#{key}")
        end
      end

      # The `view` group is named by whichever heading is showing; the
      # controller moves it when the period changes.
      def preference_view_heading = preference_current[:period] == :weekly ? "week" : "month"

      def preference_label(question, value)
        shadcn_t("event_calendar.#{OPTION_KEYS.fetch(question) % value}")
      end

      def preference_answers(form, question, applies, labelled)
        return preference_limit(form, applies, labelled) if question == :max_chips

        preference_radios(form, question, applies, labelled)
      end

      # The number a capped cell starts from when the person types one: the
      # reading's own limit. A reading without a cap has the default.
      def preference_chip_count = Workload::Component::MAX_CHIPS

      # Two radios, "at most [n]" and "All". The group's hidden input carries
      # which one is chosen and submits only "all"; the number field carries
      # the typed limit. Each is enabled only while its answer is the chosen
      # one, so the form sends one `preferences[max_chips]`. The controller
      # keeps that true as the answers change (`limitPreferences`).
      def preference_limit(form, applies, labelled)
        current = preference_current[:max_chips]
        choice = current == :all ? "all" : "number"
        count = current.is_a?(Integer) ? current : preference_chip_count

        render(RadioGroup::Component.new(
          name: form.field_name(:max_chips), value: choice, "aria-labelledby": labelled,
          "data-preferences-limit": "", input_attributes: { disabled: (true unless applies && choice == "all") }.compact
        )) do
          safe_join([ preference_limit_number(form, choice, count, applies), preference_option(form, :max_chips, "all", choice) ])
        end
      end

      def preference_limit_number(form, choice, count, applies)
        radio = preference_id(:max_chips, "number")
        label = preference_id(:max_chips, "number-label")

        tag.div(
          safe_join([
            render(RadioGroup::Item::Component.new(value: "number", checked: choice == "number", id: radio,
                                                   "aria-labelledby": label)),
            render(Label::Component.new(for: radio, id: label)) { shadcn_t("event_calendar.preferences.max_chips_number") },
            render(Input::Component.new(
              type: "number", name: form.field_name(:max_chips), value: count, id: preference_id(:max_chips, "count"),
              min: Preferences::MAX_CHIPS_RANGE.min, max: Preferences::MAX_CHIPS_RANGE.max, step: 1, required: true,
              inputmode: "numeric", "aria-labelledby": label, class: PREFERENCES_LIMIT_INPUT_CLASS,
              disabled: (true unless applies && choice == "number"),
              "data-shadcn--event-calendar-target": "preferencesLimit"
            ))
          ]),
          "data-slot": "event-calendar-preference-option", class: "flex items-center gap-2"
        )
      end

      def preference_options(question)
        # Not `filter_map`, which drops a falsy answer: the show-all question it
        # replaced lost `false` that way and asked with one choice.
        preference_table.sets.select { |set| set.key?(question) }.map { |set| set[question] }.uniq
      end

      def preference_radios(form, question, applies, labelled)
        selected = preference_current.fetch(question) { preference_options(question).first }

        render(RadioGroup::Component.new(
          name: form.field_name(question), value: selected, "aria-labelledby": labelled,
          input_attributes: { disabled: (true unless applies) }.compact
        )) do
          safe_join(preference_options(question).map { |value| preference_option(form, question, value, selected) })
        end
      end

      def preference_option(form, question, value, selected)
        id = preference_id(question, value)
        tokens = (preference_table.when(question, value) if question == :view)
        shown = tokens.nil? || tokens.include?(preference_current[:period].to_s)

        tag.div(
          safe_join([
            render(RadioGroup::Item::Component.new(value:, checked: value == selected, id:)),
            render(Label::Component.new(for: id)) { preference_label(question, value) }
          ]),
          "data-slot": "event-calendar-preference-option", class: "flex items-center gap-2",
          "data-preferences-when": tokens&.join(" "), hidden: (true unless shown)
        )
      end
    end
  end
end
