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

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/lookbook")
end
