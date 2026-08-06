# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Dialog", :js do
  let(:content) { "[data-slot=dialog-content]" }
  let(:overlay) { "[data-slot=dialog-overlay]" }

  before do
    visit_preview(:dialog)
    wait_for_stimulus
  end

  it "starts closed and hidden" do
    expect(state_of(content)).to eq("closed")
    expect(page).to have_no_css(content) # `hidden` really hides it
  end

  it "opens from the trigger" do
    click_button "Edit profile"

    expect(page).to have_css(content)
    expect(state_of(content)).to eq("open")
    expect(state_of(overlay)).to eq("open")
    expect(page).to have_css("[data-slot=dialog-title]", text: "Edit profile")
  end

  it "marks the trigger expanded and points it at the content" do
    click_button "Edit profile"

    trigger = find("[data-slot=dialog-trigger]")
    expect(trigger["aria-expanded"]).to eq("true")
    expect(trigger["aria-controls"]).to eq(find(content)["id"])
  end

  it "moves focus into the dialog and locks body scrolling" do
    click_button "Edit profile"

    expect(page.evaluate_script("document.querySelector('#{content}').contains(document.activeElement)"))
      .to be(true)
    expect(page.evaluate_script("document.body.style.overflow")).to eq("hidden")
  end

  it "traps Tab inside the dialog" do
    click_button "Edit profile"

    inside = -> { page.evaluate_script("document.querySelector('#{content}').contains(document.activeElement)") }
    12.times do
      press(:tab)
      expect(inside.call).to be(true)
    end
  end

  it "closes on Escape and gives focus back to the trigger" do
    click_button "Edit profile"
    press(:escape)

    expect(page).to have_no_css(content)
    expect(state_of(content)).to eq("closed")
    expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("dialog-trigger")
    expect(page.evaluate_script("document.body.style.overflow")).to eq("")
  end

  # This is the bug the no-portal decision exists to avoid: the close button is
  # inside the content, and a Stimulus action on it has to keep firing.
  it "closes from the close button inside the content" do
    click_button "Edit profile"
    within(content) { click_button "Cancel" }

    expect(page).to have_no_css(content)
  end

  it "closes when the overlay is clicked" do
    click_button "Edit profile"
    click_outside

    expect(page).to have_no_css(content)
  end

  # Escape used to be swallowed at the document capture phase, so a host app's
  # own keyboard handling broke whenever any layer was open.
  it "lets Escape through to the page as well" do
    page.execute_script("window.__escapes = 0; document.addEventListener('keydown', e => { if (e.key === 'Escape') window.__escapes++ })")

    click_button "Edit profile"
    press(:escape)

    expect(page).to have_no_css(content)
    expect(page.evaluate_script("window.__escapes")).to eq(1)
  end

  it "can be reopened after closing" do
    2.times do
      click_button "Edit profile"
      expect(page).to have_css(content)
      press(:escape)
      expect(page).to have_no_css(content)
    end
  end
end

RSpec.describe "AlertDialog", :js do
  let(:content) { "[data-slot=alert-dialog-content]" }

  before do
    visit_preview(:alert_dialog)
    wait_for_stimulus
    click_button "Delete account"
    expect(page).to have_css(content)
  end

  it "is an alertdialog, not a dialog" do
    expect(find(content)["role"]).to eq("alertdialog")
  end

  # Radix deliberately keeps an alert dialog open on an outside click: the user
  # has to choose an action.
  it "ignores a click on the overlay" do
    click_outside

    expect(page).to have_css(content)
    expect(state_of(content)).to eq("open")
  end

  it "still closes on Escape" do
    press(:escape)

    expect(page).to have_no_css(content)
  end

  it "closes from Cancel and from Continue" do
    within(content) { click_button "Cancel" }
    expect(page).to have_no_css(content)

    click_button "Delete account"
    within(content) { click_button "Continue" }
    expect(page).to have_no_css(content)
  end
end

RSpec.describe "Sheet", :js do
  let(:content) { "[data-slot=sheet-content]" }

  before do
    visit_preview(:sheet)
    wait_for_stimulus
  end

  it "opens from the side it was given" do
    click_button "Left"

    opened = all(content, visible: true).first
    expect(opened["data-state"]).to eq("open")
    expect(opened[:class]).to include("inset-y-0", "left-0")
  end

  it "closes on Escape" do
    click_button "Right"
    expect(page).to have_css(content)

    press(:escape)
    expect(page).to have_no_css(content)
  end
end
