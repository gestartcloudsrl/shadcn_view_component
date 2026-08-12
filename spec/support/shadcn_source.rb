# frozen_string_literal: true

require "pathname"
require "ripper"
require "set"

# Reads the vendored shadcn/ui TSX and the Ruby ports and extracts the Tailwind
# class tokens from each, so `parity_spec.rb` can compare them.
#
# What this can and cannot prove is worth being precise about, because it is
# easy to over-read. It compares *sets of class tokens per family*. It catches a
# class that was dropped, mistyped, or invented. It does **not** know which part
# or which variant a class belongs to — for that, see `snapshot_spec.rb`, which
# diffs the rendered HTML.
module ShadcnSource
  ROOT = Pathname(__dir__).join("../..").expand_path
  VENDOR = ROOT.join("vendor/shadcn/ui")
  COMPONENTS = ROOT.join("app/components/shadcn")

  # A token has to look like a Tailwind utility: some punctuation Tailwind uses
  # (`:`, `-`, `/`, `[`) and nothing that marks it as a path or a URL.
  #
  # The backslash is in there for one component: `calendar.tsx` writes two of
  # its classes with `String.raw` so that `[.rdp-button\_next>svg]` keeps its
  # escape. Measured across the whole vendored corpus before widening this —
  # those two tokens are the only thing it admits, and both are real classes.
  SHAPE = %r{\A[a-zA-Z0-9@!:.\[\]()'*&>=,%_/\\-]+\z}
  PUNCTUATION = %r{[:\-/\[]}
  NOT_A_CLASS = %r{\A(?:@/|https?|\./|\.\./)|://}

  class << self
    def vendored_components
      Dir[VENDOR.join("*.tsx")].map { |path| File.basename(path, ".tsx") }.sort
    end

    # Every Tailwind class the TSX emits, from its string literals. Import
    # statements are dropped first — including the multi-line form — because
    # package names like "radix-ui" are shaped exactly like utilities.
    IMPORT = /^import\b[\s\S]*?from\s*["'][^"']+["']\s*$|^import\s*["'][^"']+["']\s*$/

    # Both spellings of a string literal, because a class can be written in
    # either: `calendar.tsx` reaches for `String.raw` — a backtick literal — to
    # keep a backslash it needs, and a scanner that reads only `"…"` reports
    # those classes as invented by the port. `reverse_parity_spec` calls this
    # too, so the two directions cannot disagree about what a literal is.
    def string_literals(source)
      body = source.gsub(IMPORT, "")

      body.scan(/"([^"\\\n]*(?:\\.[^"\\\n]*)*)"/m).flatten + body.scan(/`([^`\n]*)`/).flatten
    end

    def tsx_classes(name)
      string_literals(VENDOR.join("#{name}.tsx").read)
        .flat_map { |literal| literal.split(/\s+/) }
        .select { |token| class_like?(token) }
        .uniq
    end

    # Every class token in the family's Ruby sources.
    #
    # Literals come from Ripper rather than a regex over the raw text, so a class
    # sitting in a comment or in dead code cannot count as ported — which a
    # source-text scan happily allowed.
    #
    # Previews are excluded: they demonstrate usage and may add classes of their
    # own.
    def ruby_classes(directory, also: [])
      ruby_files(directory, also)
        .flat_map { |path| ruby_string_literals(path.read) }
        .flat_map { |literal| literal.split(/\s+/) }
        .to_set
    end

    private

    # A family is its directory plus the sibling `<family>.rb` holding the
    # `part` declarations.
    def ruby_files(directory, also)
      [ directory, *also ].flat_map do |family|
        Dir[COMPONENTS.join(family, "**/*.rb")] + Dir[COMPONENTS.join("#{family}.rb")]
      end
        .reject { |path| File.basename(path) == "preview.rb" }
        .map { |path| Pathname(path) }
    end

    # Ripper hands back only the actual contents of string literals — comments,
    # identifiers and method names never appear.
    def ruby_string_literals(source)
      Ripper.lex(source).filter_map { |(_pos, type, token, _state)| token if type == :on_tstring_content }
    end

    def class_like?(token)
      return false if token.empty?
      return false if token.match?(NOT_A_CLASS)
      return false unless token.match?(SHAPE)

      # Punctuation on its own is punctuation. `carousel.tsx` throws
      # `"useCarousel must be used within a <Carousel />"`, and `/>` has a
      # slash, so it reached the comparison and was reported as a class the port
      # had dropped. Every Tailwind utility has a letter in it.
      return false unless token.match?(/[a-z]/i)

      # Bare words without Tailwind punctuation are prose or attribute values
      # ("button", "vertical", "alert"), not utilities.
      token.match?(PUNCTUATION)
    end
  end
end
