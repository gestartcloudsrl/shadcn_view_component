# frozen_string_literal: true

# Lookbook renders *every* main inspector panel eagerly, whichever tab is
# showing, and its "HTML" panel is the rendered output run through a
# line-numbered code viewer — one `<span>` per token. On a dense preview that is
# twenty thousand extra nodes on a page whose preview lives in an iframe and
# costs none of them.
#
# The browser's own parser takes it in its stride: reloading the workload
# preview built the whole page in 517 ms with no long task at all. Turbo does
# not — it parses the response and swaps the body in one synchronous go, and the
# same page cost a single 4.5-second long task when reached by clicking through
# the sidebar, which is why it was slow to arrive at and fine to refresh. The
# panel is what scales: 331 nodes cost 95 ms, 20,433 cost 4,527. Without it the
# navigation has no long task at all.
#
# So the gallery does not show it. What a component emits is in
# `spec/fixtures/snapshots/` and in the browser's own inspector, both of which
# answer that question better than a tab does.
#
# Removed rather than dropped from `preview_inspector.main_panels`: assigning
# that list from here has no effect, because Lookbook has already read it by the
# time `config/initializers` runs. `remove_panel` raises on a name that is
# already gone, and a dev reload runs this more than once, so the guard is not
# decoration.
Lookbook.remove_panel(:output) if Lookbook::Engine.panels.get_panel(:output)
