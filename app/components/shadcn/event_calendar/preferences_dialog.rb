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
        group: "group.label", shape: "hours.label", show_all: "group.show_all"
      }.freeze

      OPTION_KEYS = {
        period: "period.%s", view: "view.%s", showing: "daily.%s",
        group: "group.%s", shape: "hours.%s", show_all: "preferences.show_all_%s"
      }.freeze

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

      def preference_urls
        preference_table.sets.to_h { |set| [ Preferences.key(set), @preferences_url.call(set) ] }
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
          dialog.with_dialog_content do |content|
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
                  class: "flex flex-col gap-4",
                  data: { "shadcn--event-calendar-target": "preferencesForm", action: }) do |form|
          safe_join([
            *Preferences::QUESTIONS.filter_map { |question| preference_question(form, question) },
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
          safe_join([ *preference_headings(form, question), preference_radios(form, question, applies, labelled) ]),
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

      def preference_options(question)
        preference_table.sets.filter_map { |set| set[question] }.uniq
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
            render(Label::Component.new(for: id)) { shadcn_t("event_calendar.#{OPTION_KEYS.fetch(question) % value}") }
          ]),
          "data-slot": "event-calendar-preference-option", class: "flex items-center gap-2",
          "data-preferences-when": tokens&.join(" "), hidden: (true unless shown)
        )
      end
    end
  end
end
