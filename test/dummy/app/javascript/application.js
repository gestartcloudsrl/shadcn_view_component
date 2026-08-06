// The dummy app runs Turbo on purpose: a Rails 8 component library has to work
// under Turbo Drive's page caching and under morph refreshes, and the only way
// to know is to load it that way.
import "@hotwired/turbo-rails"

import { Application } from "@hotwired/stimulus"
import { registerShadcnControllers } from "shadcn"

const application = Application.start()
application.debug = false
window.Stimulus = application

registerShadcnControllers(application)
