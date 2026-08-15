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
  def audit(within: nil, excluding: nil)
    check = Axe::Matchers::BeAxeClean.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    check = check.within(within) if within
    check = check.excluding(excluding) if excluding

    expect(page).to check
  end

  # Nodes this port renders that axe fails and that the port is not free to
  # change, because the colours are upstream's own. One entry, and it is here
  # rather than fixed for the reason the whole project turns on: upstream wins
  # on markup.
  #
  # `attachment-description` takes `text-destructive/80` while the attachment is
  # in its error state (vendor/shadcn/ui/attachment.tsx:119). Measured by axe in
  # the theme this suite runs: 4.36:1 at 12px, where AA wants 4.5:1. Raising the
  # opacity would fix it and would put a class in the bundle that upstream does
  # not emit, which `parity_spec` exists to catch.
  #
  # Scoped to the error state rather than to the slot, so the same element is
  # still audited everywhere else it appears.
  upstream_contrast = {
    "attachment" => "[data-state=error] [data-slot=attachment-description]"
  }.freeze

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

  previews.each do |family, example|
    it "#{family}/#{example} has no violations at rest" do
      visit_preview(family, example)
      wait_for_stimulus

      audit(excluding: upstream_contrast[family])
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

  # Contrast is the one thing that genuinely differs between the two modes, so
  # this is a curated handful rather than every family again.
  context "when the dark class is on" do
    def expect_contrast(family, example = :default)
      visit_preview(family, example)
      wait_for_stimulus
      page.execute_script("document.documentElement.classList.add('dark')")

      expect(page).to be_axe_clean.checking_only(:"color-contrast")
    end

    it("keeps the button variants readable") { expect_contrast("button", :variants) }
    it("keeps the badge readable") { expect_contrast("badge") }
    it("keeps the alert readable") { expect_contrast("alert") }
    it("keeps the card readable") { expect_contrast("card") }
    it("keeps the field readable") { expect_contrast("field") }
    it("keeps the table readable") { expect_contrast("table") }
  end
end
