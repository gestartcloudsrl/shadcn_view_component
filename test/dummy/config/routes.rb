Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook"

  # Linked pages for the Turbo system specs.
  get "turbo-probe/one" => "turbo_probe#one", as: :turbo_probe_one
  get "turbo-probe/two" => "turbo_probe#two", as: :turbo_probe_two

  # A full-page layout, which a Lookbook preview cannot give.
  get "sidebar" => "sidebar#show", as: :sidebar

  # The message scroller doing its job rather than demonstrating itself: a
  # Lookbook preview cannot give it a page to be the height of.
  get "chat" => "chat#show", as: :chat

  # The day view behind the event calendar's `day_url:`. A Lookbook preview can
  # render the calendar but cannot answer its links, so the route lives here.
  get "calendar/days/:date" => "calendar#day", as: :calendar_day

  # One event, answering the `<turbo-frame id="event">` an agenda row points at.
  get "calendar/events/:id" => "calendar#event", as: :calendar_event

  # The host half of the calendar's `preferences: :host`: the dialog's form is
  # posted here, kept in the session and shown back, which is all a spec needs
  # to read what arrived.
  patch "calendar/preferences" => "calendar#save_preferences", as: :calendar_preferences
  get "calendar/preferences" => "calendar#preferences"

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/lookbook")
end
