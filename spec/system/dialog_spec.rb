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

  # Escape used to be swallowed at the document capture phase, so a host app's
  # own keyboard handling broke whenever any layer was open. The listener has to
  # go on before the dialog opens.
  it "lets Escape through to the page as well" do
    page.execute_script(
      "window.__escapes = 0;" \
      "document.addEventListener('keydown', e => { if (e.key === 'Escape') window.__escapes++ })"
    )

    click_button "Edit profile"
    press(:escape)

    expect(page).to have_no_css(content)
    expect(page.evaluate_script("window.__escapes")).to eq(1)
  end

  context "when opened from the trigger" do
    before { click_button "Edit profile" }

    it "shows the content and the overlay" do
      expect(page).to have_css(content)
      expect(state_of(content)).to eq("open")
      expect(state_of(overlay)).to eq("open")
      expect(page).to have_css("[data-slot=dialog-title]", text: "Edit profile")
    end

    it "marks the trigger expanded and points it at the content", :aggregate_failures do
      trigger = find("[data-slot=dialog-trigger]")

      expect(trigger["aria-expanded"]).to eq("true")
      expect(trigger["aria-controls"]).to eq(find(content)["id"])
    end

    it "moves focus into the dialog and locks body scrolling" do
      expect(page.evaluate_script("document.querySelector('#{content}').contains(document.activeElement)"))
        .to be(true)
      expect(page.evaluate_script("document.body.style.overflow")).to eq("hidden")
    end

    it "traps Tab inside the dialog" do
      inside = -> { page.evaluate_script("document.querySelector('#{content}').contains(document.activeElement)") }

      12.times do
        press(:tab)
        expect(inside.call).to be(true)
      end
    end

    it "closes on Escape and gives focus back to the trigger" do
      press(:escape)

      expect(page).to have_no_css(content)
      expect(state_of(content)).to eq("closed")
      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("dialog-trigger")
      expect(page.evaluate_script("document.body.style.overflow")).to eq("")
    end

    # This is the bug the no-portal decision exists to avoid: the close button is
    # inside the content, and a Stimulus action on it has to keep firing.
    it "closes from the close button inside the content" do
      within(content) { click_button "Cancel" }

      expect(page).to have_no_css(content)
    end

    it "closes when the overlay is clicked" do
      click_outside

      expect(page).to have_no_css(content)
    end

    it "can be reopened after closing" do
      press(:escape)
      expect(page).to have_no_css(content)

      click_button "Edit profile"

      expect(page).to have_css(content)
    end
  end
end

RSpec.describe "AlertDialog", :js do
  let(:content) { "[data-slot=alert-dialog-content]" }

  before do
    visit_preview(:alert_dialog)
    wait_for_stimulus
    click_button "Delete account"
    expect(page).to have_css(content) # the examples below all assume it opened
  end

  it "is an alertdialog, not a dialog" do
    expect(find(content)["role"]).to eq("alertdialog")
  end

  # Radix deliberately keeps an alert dialog open on an outside click: the user
  # has to choose an action.
  context "when the overlay is clicked" do
    it "stays open" do
      click_outside

      expect(page).to have_css(content)
      expect(state_of(content)).to eq("open")
    end
  end

  it "still closes on Escape" do
    press(:escape)

    expect(page).to have_no_css(content)
  end

  it "closes from Cancel" do
    within(content) { click_button "Cancel" }

    expect(page).to have_no_css(content)
  end

  it "closes from Continue" do
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

  context "when opened from a side" do
    it "renders against that edge" do
      click_button "Left"

      opened = all(content, visible: true).first

      expect(opened["data-state"]).to eq("open")
      expect(opened[:class]).to include("inset-y-0", "left-0")
    end
  end

  it "closes on Escape" do
    click_button "Right"
    expect(page).to have_css(content)

    press(:escape)

    expect(page).to have_no_css(content)
  end
end

# A `role="dialog"` with no name is announced as "dialog" and nothing else, and
# a host's `getByRole("dialog", { name: … })` cannot find it. Every modal the
# shared controller drives — Dialog, AlertDialog, Sheet, Drawer — takes its name
# from its own Title and its description from its own Description.
RSpec.describe "A modal's name", :js do
  def named(content)
    page.evaluate_script(<<~JS, content)
      ((content) => {
        const text = (attribute) => (content.getAttribute(attribute) || "").split(/\\s+/).filter(Boolean)
          .map((id) => document.getElementById(id)?.textContent.trim()).join(" ")
        return { name: text("aria-labelledby"), description: text("aria-describedby") }
      })(arguments[0])
    JS
  end

  {
    dialog: [ "Edit profile", "Make changes to your profile here. Click save when you are done." ],
    alert_dialog: [ "Are you absolutely sure?", "This action cannot be undone. It will permanently delete your account." ],
    sheet: [ "Edit profile", "Make changes to your profile here." ],
    drawer: [ "Move goal", "Set your daily activity goal." ]
  }.each do |family, (title, description)|
    it "names the #{family} from its title and describes it from its description", :aggregate_failures do
      visit_preview(family)
      wait_for_stimulus
      slot = family.to_s.tr("_", "-")
      first("[data-slot=#{slot}-trigger]").click
      content = find("[data-slot=#{slot}-content][data-state=open]")

      expect(named(content)).to eq("name" => title, "description" => description)
    end
  end

  # A name the caller gave is the caller's. The controller has already wired
  # the title at connect, so the example stands in for a server-rendered
  # `aria-label` by swapping the two before the dialog renders again.
  it "leaves an aria-label the caller set" do
    visit_preview(:dialog)
    wait_for_stimulus
    page.execute_script(<<~JS)
      const content = document.querySelector("[data-slot=dialog-content]")
      content.removeAttribute("aria-labelledby")
      content.setAttribute("aria-label", "Mine")
    JS
    click_button "Edit profile"

    expect(find("[data-slot=dialog-content][data-state=open]")["aria-labelledby"]).to be_nil
  end
end
