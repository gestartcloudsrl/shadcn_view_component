# frozen_string_literal: true

# The dummy is a host application, so it registers the icons it wants the way
# the README tells one to: through `ShadcnViewComponent::IconRegistry`, from an
# initializer, against the `lib/` constant that resolves at boot.
#
# The gem bundles only the icons its own components render; the command
# palette's preview asks for five more. Drawings copied from
# `lucide-static@1.31.0` rather than retyped — one of them was wrong when it
# was.
ICONS = {
  "calendar" => %(<path d="M8 2v3"/> <path d="M16 2v3"/> <rect x="3" y="3" width="18" height="18" rx="2"/> <path ) +
                   %(d="M3 9h18"/>),
  "calculator" => %(<rect width="16" height="20" x="4" y="2" rx="2"/> <line x1="8" x2="16" y1="6" y2="6"/> <line ) +
                   %(x1="16" x2="16" y1="14" y2="18"/> <path d="M16 10h.01"/> <path d="M12 10h.01"/> <path d="M8 ) +
                   %(10h.01"/> <path d="M12 14h.01"/> <path d="M8 14h.01"/> <path d="M12 18h.01"/> <path d="M8 ) +
                   %(18h.01"/>),
  "user" => %(<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/> <circle cx="12" cy="7" r="4"/>),
  "credit-card" => %(<rect width="20" height="14" x="2" y="5" rx="2"/> <line x1="2" x2="22" y1="10" y2="10"/>),
  "settings" => %(<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 ) +
                   %(4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 ) +
                   %(0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 ) +
                   %(2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/> <circle cx="12" cy="12" r="3"/>)
}.freeze

ICONS.each { |name, drawing| ShadcnViewComponent::IconRegistry.register(name, drawing) }
