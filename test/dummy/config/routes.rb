Rails.application.routes.draw do
  mount Lookbook::Engine, at: "/lookbook"

  # Linked pages for the Turbo system specs.
  get "turbo-probe/one" => "turbo_probe#one", as: :turbo_probe_one
  get "turbo-probe/two" => "turbo_probe#two", as: :turbo_probe_two

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/lookbook")
end
