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
  def audit(within: nil)
    check = Axe::Matchers::BeAxeClean.new.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    check = check.within(within) if within

    expect(page).to check
  end

  # Read off disk rather than typed out, so a component added tomorrow is
  # audited without anyone remembering to add it here.
  families = Dir[Pathname(__dir__).join("../../app/components/shadcn/*/previews/default.html.erb")]
             .map { |path| Pathname(path).parent.parent.basename.to_s }
             .sort

  it "found the previews it audits" do
    expect(families.size).to be >= 35
  end

  families.each do |family|
    it "#{family} has no violations at rest" do
      visit_preview(family)
      wait_for_stimulus

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
