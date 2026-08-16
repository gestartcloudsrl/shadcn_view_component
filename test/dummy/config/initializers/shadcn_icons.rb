# frozen_string_literal: true

# The dummy is a host application, so it adds icons the way the README tells
# one to: SVG files in a directory, and one line pointing the registry at them.
# The gem bundles only what its own components render; the previews ask for six
# more — five in the command palette, and the sidebar's `chevrons-up-down`,
# which no component draws.
#
# This used to be five drawings pasted into this file, with a comment saying
# they had been copied from lucide-static rather than retyped because retyping
# one had got it wrong. `load_directory` is that comment turned into code.
ShadcnViewComponent::IconRegistry.load_directory(Rails.root.join("app/assets/icons"))
