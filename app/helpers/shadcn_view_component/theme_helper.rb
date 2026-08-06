# frozen_string_literal: true

module ShadcnViewComponent
  # View helpers for the theming system.
  #
  #   <html>
  #     <head><%= shadcn_theme_script_tag %></head>
  #     <body class="<%= shadcn_theme_class %>">
  #
  # `shadcn_theme_script_tag` is what stops the flash of the wrong palette: it
  # runs before the first paint, reads the stored preference and puts `.dark`
  # and `data-shadcn-theme` on <html> itself, since <body> does not exist yet.
  module ThemeHelper
    MODE_COOKIE = "shadcn-ui-mode"
    THEME_COOKIE = "shadcn-ui-theme"

    # Emits the blocking snippet that applies the stored preference before the
    # page paints. Put it in <head>, as early as possible.
    #
    # @param default_mode [String] "system", "light" or "dark"
    # @param default_theme [String] a name from ShadcnViewComponent::Themes
    def shadcn_theme_script_tag(default_mode: "system", default_theme: Themes::DEFAULT)
      javascript_tag(nonce: true) do
        raw(<<~JS)
          (function () {
            try {
              var root = document.documentElement;
              var mode = localStorage.getItem("#{MODE_COOKIE}") || "#{default_mode}";
              var theme = localStorage.getItem("#{THEME_COOKIE}") || "#{default_theme}";
              var dark = mode === "dark" ||
                (mode === "system" && matchMedia("(prefers-color-scheme: dark)").matches);

              root.classList.toggle("dark", dark);
              root.style.colorScheme = dark ? "dark" : "light";
              root.dataset.shadcnTheme = theme;
            } catch (e) {}
          })();
        JS
      end
    end

    # The colour theme this request should render with, from the cookie the
    # store mirrors its `localStorage` value into. Lets a server-rendered page
    # be correct on the very first byte.
    def shadcn_theme_name(default: Themes::DEFAULT)
      name = cookies[THEME_COOKIE].to_s
      Themes.exists?(name) ? name : default
    end

    # The class to put on <body>.
    def shadcn_theme_class(default: Themes::DEFAULT)
      "theme-#{shadcn_theme_name(default:)}"
    end

    # The mode this request should render with: "light", "dark" or "system".
    def shadcn_mode(default: "system")
      mode = cookies[MODE_COOKIE].to_s
      %w[light dark system].include?(mode) ? mode : default
    end
  end
end
