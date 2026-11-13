# frozen_string_literal: true

require "spec_helper"
require "axe-rspec"

# The gem's pitch is that it reproduces Radix's accessibility. Transcribing the
# ARIA is not the same as verifying it, so this runs axe over every family —
# once at rest, and again with the interactive ones open, since a menu or a
# dialog only exists in the DOM after it has been opened.
#
# axe catches machine-checkable violations: contrast, names, roles, required
# parents and children, focusability. It does not replace a screen reader.
RSpec.describe "Accessibility", :js do
  # WCAG 2.1 AA is what shadcn's own components target.
  def audit(within: nil, excluding: nil, skipping: nil)
    check = Axe::Matchers::BeAxeClean.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    check = check.within(within) if within
    check = check.excluding(excluding) if excluding
    check = check.skipping(skipping) if skipping

    expect(page).to check
  end

  # WCAG 2.5.3, *Label in Name*: a control's accessible name has to contain the
  # text it shows. axe 4.13 carried the rule as experimental and did not run
  # it; 4.14 runs it by default, and it is what found the zero-padded day names
  # ("August 01" on a button showing "1") and the searchable select's trigger.
  def label_in_name = :"label-content-name-mismatch"

  # The one place the rule is set aside, and only the rule, only on these nodes.
  #
  # An event-calendar day is a single target whose *label* is its date — the
  # number on its face, which its name ("Saturday, August 1, 2026, 3 events")
  # contains. What else it shows, the chips and the "+N", is a picture of the
  # day drawn inside the target on purpose (see the event-content design,
  # 2026-11-09): the events open from the list underneath, not from here. axe
  # cannot tell a label from a picture and counts every glyph, so every day
  # with anything on it failed. Naming the day by its content instead would
  # read a screen-reader user "Sat 1 3 10:44 AM AT GH LP +1 Fabbri Srl…";
  # moving the chips out of the button is a markup change the design rejected.
  #
  # Skipping the rule page-wide would also stop it checking everything else on
  # the page, so the page is audited without it and then again with it alone,
  # minus these nodes. Contrast and every other rule still reach the day and
  # its chips.
  label_in_name_exemptions = {
    "event_calendar" => "[data-slot=event-calendar-day]"
  }.freeze

  def audit_label_in_name(excluding:)
    expect(page).to Axe::Matchers::BeAxeClean.new.checking_only(label_in_name).excluding(excluding)
  end

  # Nodes this port renders that axe fails and that the port is not free to
  # change, because the colours are upstream's own — the rule the whole project
  # turns on is that upstream wins on markup. Each entry carries the measurement
  # and the line it comes from, so raising an opacity or darkening a token can
  # be recognised for what it would be: a class in the bundle that upstream does
  # not emit, which `parity_spec` exists to catch.
  #
  # Everything here failed in the *light* palette, which nothing audited until
  # the colour scheme was pinned — see `spec/support/system.rb`. The suite had
  # been reading whichever palette the machine preferred.
  upstream_contrast = {
    # `text-destructive` on `bg-destructive/10` while the attachment is in its
    # error state (attachment.tsx:49 for the pair, :119 for the description).
    # 4.00:1 at 10px on the file-type badge, 4.36:1 at 12px on the description,
    # where AA wants 4.5:1. Scoped to the error state, so the same elements are
    # still audited everywhere else they appear.
    "attachment" => "[data-state=error] [data-slot=attachment-description], " \
                    "[data-state=error] [data-slot=attachment-media]",
    # The same pair, in the bubble's destructive variant (bubble.tsx:27-31).
    "bubble" => "[data-variant=destructive] [data-slot=bubble-content]"
  }.freeze

  # `text-muted-foreground` on `bg-muted` — 4.34:1 at 14px, and 4.34:1 at 12px
  # for the small avatar. Upstream's own string, character for character
  # (avatar.tsx:49 for the fallback, :94 for the group count), out of upstream's
  # own tokens: `muted: oklch(0.97 0 0)` against `muted-foreground:
  # oklch(0.556 0 0)` in `vendor/shadcn/themes.json`.
  #
  # Light only, and that is the point of keeping it apart: in the dark palette
  # the same two elements measure 5.85:1 and are audited normally. A host that
  # has to meet AA overrides `--muted-foreground`; the README says so.
  #
  # It is not keyed by family because an avatar turns up inside six of them.
  light_contrast = "[data-slot=avatar-fallback], [data-slot=avatar-group-count]"

  # The same kind of entry, keyed by family because it is one family's, and
  # light only for the same reason as the avatar's: the dark palette passes.
  #
  # The destructive alert's description is `text-destructive/90` on the card
  # (alert.tsx:13): axe 4.14 measures 4.49:1 at 14px where AA wants 4.5:1.
  # axe 4.13 passed the same markup and the same compiled CSS — checked by
  # pinning one and then the other — so what changed is the measurement, not
  # the port. Why 4.14 reads it differently was not investigated. Scoped to
  # the destructive root, so the default alert's description is still audited.
  upstream_light_contrast = {
    "alert" => "[data-slot=alert].text-destructive [data-slot=alert-description]"
  }.freeze

  # The palette is a class on the root, so both themes can be audited in one
  # visit — the page load is what costs, not the second axe run.
  def in_dark_mode
    page.execute_script("document.documentElement.classList.add('dark')")
    yield
  ensure
    page.execute_script("document.documentElement.classList.remove('dark')")
  end

  def excluding(*selectors) = selectors.compact.join(", ").presence

  # Read off disk rather than typed out, so a component added tomorrow is
  # audited without anyone remembering to add it here — and *every* preview,
  # not only each family's `default`. That was the shape until the gallery grew
  # a second and third example per family: a variant shown nowhere else was
  # audited nowhere, while `CLAUDE.md` said adding a preview is what gets it
  # covered. It says that because this reads them all.
  previews = Dir[Pathname(__dir__).join("../../app/components/shadcn/*/previews/*.html.erb")]
             .map { |path|
               p = Pathname(path)
               [ p.parent.parent.basename.to_s, p.basename(".html.erb").to_s ]
             }
             .sort

  it "found the previews it audits" do
    expect(previews.map(&:first).uniq.size).to be >= 35
    expect(previews.size).to be > previews.map(&:first).uniq.size
  end

  # Both palettes, because contrast is measured against what is on the screen
  # and there are two of them. This is the pass that was auditing one palette by
  # accident — whichever one the machine reported — for the life of the project.
  previews.each do |family, example|
    it "#{family}/#{example} has no violations at rest, in either theme", :aggregate_failures do
      visit_preview(family, example)
      wait_for_stimulus

      exempt = label_in_name_exemptions[family]
      skipping = (label_in_name if exempt)

      audit(excluding: excluding(upstream_contrast[family], upstream_light_contrast[family], light_contrast),
            skipping:)
      in_dark_mode { audit(excluding: excluding(upstream_contrast[family]), skipping:) }
      audit_label_in_name(excluding: exempt) if exempt
    end
  end

  # The audit runs every preview at 1400×900, where the sidebar renders its
  # desktop tree and the sheet does not exist — so for as long as this spec has
  # existed it has never seen the one branch that is a modal. It is also the
  # branch that shipped with no role and no name.
  context "with the sidebar's mobile sheet open" do
    before { page.driver.browser.manage.window.resize_to(375, 667) }
    after { page.driver.browser.manage.window.resize_to(1400, 900) }

    it "has no violations" do
      visit "/sidebar"
      wait_for_stimulus
      find("[data-slot=sidebar-trigger]").click
      expect(page).to have_css("[data-slot=sidebar-container][role=dialog]")

      audit
    end
  end

  context "with the dialog open" do
    it "has no violations" do
      visit_preview(:dialog)
      wait_for_stimulus
      click_button "Edit profile"
      expect(page).to have_css("[data-slot=dialog-content]")

      audit
    end
  end

  # The calendar's own dialog, the one with nine radio groups and two headings
  # for one of them. Audited within itself, because the days behind it carry
  # the label-in-name exemption above and this is not about them.
  context "with the event calendar's preferences open" do
    it "has no violations" do
      visit_preview(:event_calendar, :preferences)
      wait_for_stimulus
      find("[data-slot=event-calendar] [data-slot=dropdown-menu-trigger]").click
      find("[data-slot=dropdown-menu-item]", text: "Preferences").click
      expect(page).to have_css("[data-slot=dialog-content][data-state=open]")

      audit(within: "[data-slot=dialog-content]")
    end
  end

  context "with the alert dialog open" do
    it "has no violations" do
      visit_preview(:alert_dialog)
      wait_for_stimulus
      click_button "Delete account"
      expect(page).to have_css("[data-slot=alert-dialog-content]")

      audit
    end
  end

  context "with the sheet open" do
    it "has no violations" do
      visit_preview(:sheet)
      wait_for_stimulus
      click_button "Right"
      expect(page).to have_css("[data-slot=sheet-content]")

      audit
    end
  end

  context "with the dropdown menu open" do
    it "has no violations" do
      visit_preview(:dropdown_menu)
      wait_for_stimulus
      within(all("[data-slot=dropdown-menu]").last) { find("[data-slot=dropdown-menu-trigger]").click }
      expect(page).to have_css("[data-slot=dropdown-menu-content]")

      audit
    end
  end

  context "with the select open" do
    it "has no violations" do
      visit_preview(:select)
      wait_for_stimulus
      within(all("[data-slot=select]").last) { find("[data-slot=select-trigger]").click }
      expect(page).to have_css("[data-slot=select-content]")

      audit
    end
  end

  # The loop above audits each family's `default` preview, so it never reaches
  # this one — and this is the shape worth auditing, because it was chosen by
  # audit: a search field inside the element carrying `role="listbox"` raises
  # `aria-required-children`, critical. See decisions/01-architecture.md.
  context "with a searchable select open" do
    it "has no violations" do
      visit_preview(:select, :searchable)
      wait_for_stimulus
      within(all("[data-slot=select]").last) { find("[data-slot=select-trigger]").click }
      expect(page).to have_css("[data-slot=select-content]")

      audit
    end
  end

  context "with the popover open" do
    it "has no violations" do
      visit_preview(:popover)
      wait_for_stimulus
      find("[data-slot=popover-trigger]").click
      expect(page).to have_css("[data-slot=popover-content]")

      audit
    end
  end

  context "with the tooltip open" do
    it "has no violations" do
      visit_preview(:tooltip)
      wait_for_stimulus
      find("[data-slot=tooltip-trigger]").hover
      expect(page).to have_css("[data-slot=tooltip-content]")

      audit
    end
  end

  # The curated dark-mode contrast block that used to live here is gone: every
  # preview is now audited in both palettes by the loop above, so it was a
  # subset. It was also not doing what it said — it added `.dark` to a page that
  # was already dark on the machine that wrote it, and checked one mode twice.
end
