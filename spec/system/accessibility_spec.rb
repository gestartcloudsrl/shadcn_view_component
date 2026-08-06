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
  STANDARD = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze

  def audit(within: nil)
    check = Axe::Matchers::BeAxeClean.new.according_to(*STANDARD)
    check = check.within(within) if within

    expect(page).to check
  end

  # Every family, at rest.
  %w[
    alert avatar badge breadcrumb button card checkbox collapsible field
    input kbd label native_select pagination progress radio_group select
    separator skeleton spinner switch table tabs textarea toggle toggle_group
    accordion dialog alert_dialog sheet dropdown_menu popover tooltip
    mode_toggle mode_switcher theme_selector
  ].each do |family|
    it "#{family} has no violations" do
      visit_preview(family)
      wait_for_stimulus

      audit
    end
  end

  describe "with the layer open" do
    it "dialog" do
      visit_preview(:dialog)
      wait_for_stimulus
      click_button "Edit profile"
      expect(page).to have_css("[data-slot=dialog-content]")

      audit
    end

    it "alert dialog" do
      visit_preview(:alert_dialog)
      wait_for_stimulus
      click_button "Delete account"
      expect(page).to have_css("[data-slot=alert-dialog-content]")

      audit
    end

    it "sheet" do
      visit_preview(:sheet)
      wait_for_stimulus
      click_button "Right"
      expect(page).to have_css("[data-slot=sheet-content]")

      audit
    end

    it "dropdown menu" do
      visit_preview(:dropdown_menu)
      wait_for_stimulus
      within(all("[data-slot=dropdown-menu]").last) { find("[data-slot=dropdown-menu-trigger]").click }
      expect(page).to have_css("[data-slot=dropdown-menu-content]")

      audit
    end

    it "select" do
      visit_preview(:select)
      wait_for_stimulus
      within(all("[data-slot=select]").last) { find("[data-slot=select-trigger]").click }
      expect(page).to have_css("[data-slot=select-content]")

      audit
    end

    it "popover" do
      visit_preview(:popover)
      wait_for_stimulus
      find("[data-slot=popover-trigger]").click
      expect(page).to have_css("[data-slot=popover-content]")

      audit
    end

    it "tooltip" do
      visit_preview(:tooltip)
      wait_for_stimulus
      find("[data-slot=tooltip-trigger]").hover
      expect(page).to have_css("[data-slot=tooltip-content]")

      audit
    end
  end

  describe "in dark mode" do
    # Contrast is the one thing that genuinely differs between the two modes.
    {
      "button" => :variants,
      "badge" => :default,
      "alert" => :default,
      "card" => :default,
      "field" => :default,
      "table" => :default
    }.each do |family, example|
      it "#{family} keeps its contrast" do
        visit_preview(family, example)
        wait_for_stimulus
        page.execute_script("document.documentElement.classList.add('dark')")

        expect(page).to be_axe_clean.checking_only(:"color-contrast")
      end
    end
  end
end
