Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook"

  # Linked pages for the Turbo system specs.
  get "turbo-probe/one" => "turbo_probe#one", as: :turbo_probe_one
  get "turbo-probe/two" => "turbo_probe#two", as: :turbo_probe_two

  # A full-page layout, which a Lookbook preview cannot give — and the markup
  # contract the Sidebar's components will have to emit.
  get "sidebar" => "sidebar#show", as: :sidebar

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/lookbook")
end
