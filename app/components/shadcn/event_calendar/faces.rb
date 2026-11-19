# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # The faces and flags an event carries — the avatars, the badge on a face, and
    # the two icons for done and attachment. Shared by the chips and by the
    # agenda row, and neither of those is the other's parent, so they live here
    # rather than in `Chips`.
    module Faces
      # Smaller everywhere a month is not on a desktop. Two initials at 14px
      # still read; the circle is what gives way, not the type.
      #
      # A face in a crew stack, which is not the same face as the one on an
      # assignee chip: these two shared a name after a rename and Ruby kept the
      # second, so the chip's avatar silently lost its `shrink-0` and shrank in
      # a scrolling row. `ruby -w` was the only thing that saw it — no spec did,
      # and rubocop has no cop for a reassigned constant.
      STACK_AVATAR_CLASS = "size-3.5 lg:size-4"

      # `bg-background` rather than the fallback's own `bg-muted`: the chip *is*
      # `bg-muted` now, so an avatar wearing it would be an invisible circle
      # with initials floating in it. Inverting them also lifts the initials off
      # the pair `accessibility_spec` excludes as upstream's — 4.34:1 on muted,
      # 4.74:1 on background.
      INITIALS_CLASS = "bg-background text-[0.5rem] font-medium"

      FLAG_ICON_CLASS = "size-3"
      SUBTITLE_CLASS = "font-normal"

      # Faces up to `AVATARS_CAP`, then a count.
      # `-space-x-1` overrides the group's own `-space-x-2`: upstream's overlap
      # is a quarter of a `size-8` avatar, and the same eight pixels on a
      # `size-4` one is half of it — the second initial disappears under the
      # next face. A quarter of *this* size is four.
      AVATARS_CLASS = "ml-auto flex shrink-0 -space-x-1"
      # The fourth face is a number, at the same size as the three it follows.
      AVATARS_MORE_CLASS = "size-3.5 bg-background text-[0.5rem] lg:size-4"
      # Three faces, then the fourth is the count. Five was the first guess and
      # it is too many at this size: the stack out-weighs the clock beside it,
      # and past three the faces stop being read individually anyway.
      AVATARS_CAP = 3

      # The two flags an event can carry, as icons, in the order they are
      # listed. `prefix` is the slot family they are drawn in — the chip's
      # `event-calendar-day`, the agenda row's `event-calendar-agenda` — so a
      # surface can be addressed without the other being.
      #
      # The name is the host's words when it gave some (`done: { label: }`),
      # and the gem's generic ones otherwise.
      def flag_icons(item, prefix)
        [ (done_icon(prefix, item.done_label) if item.done?),
          (attachment_icon(prefix, item.attachment_label) if item.attachment?) ]
      end

      def done_icon(prefix, label = nil)
        flag_icon("check", "#{prefix}-done", label || shadcn_t("event_calendar.done"))
      end

      def attachment_icon(prefix, label = nil)
        flag_icon("paperclip", "#{prefix}-attachment", label || shadcn_t("event_calendar.attachment"))
      end

      # The picture is decorative and the name is not: the chip's text is read
      # from inside the day's target, so an icon alone would say nothing there.
      def flag_icon(icon, slot, name)
        tag.span(safe_join([ render(Icon::Component.new(icon, class: FLAG_ICON_CLASS, "aria-hidden": "true")),
                             tag.span(name, class: "sr-only") ]),
                 "data-slot": slot, class: "inline-flex shrink-0")
      end

      # What an assignee's progress looks like on the corner of their face:
      # upstream's own badge, with `bg-muted-foreground` standing for "not yet"
      # over its `bg-primary`. An assignee with no status gets no badge at all.
      # What it says is the host's `label:` when given, the gem's word otherwise.
      def assignee_badge(avatar, assignee)
        return unless assignee.status

        avatar.with_badge(class: ("bg-muted-foreground" if assignee.status == :pending),
                          "data-status": assignee.status) do
          tag.span(assignee.label || shadcn_t("event_calendar.assignee_status.#{assignee.status}"), class: "sr-only")
        end
      end

      # `Avatar::Group` is upstream's own overlap and ring; the count past
      # `AVATARS_CAP` is its `GroupCount`, so the shape is shadcn's
      # rather than a lookalike.
      def chip_avatars(item)
        shown = item.assignees.first(AVATARS_CAP)
        rest = item.assignees.size - shown.size

        render(Avatar::Group::Component.new(class: AVATARS_CLASS)) do
        safe_join(shown.map { |assignee| avatar_for(assignee) } + [ avatars_more(rest) ].compact)
        end
      end

      def avatar_for(assignee)
        render(Avatar::Component.new(size: :sm, class: STACK_AVATAR_CLASS)) do |avatar|
        avatar.with_fallback(class: INITIALS_CLASS) { assignee.initials }
        avatar.with_image(src: assignee.image, alt: "") if assignee.image
        assignee_badge(avatar, assignee)
        end
      end

      def avatars_more(count)
        return if count.zero?

        render(Avatar::GroupCount::Component.new(class: AVATARS_MORE_CLASS)
                                          .with_content("+#{count}"))
      end
    end
  end
end
