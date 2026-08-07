require "concurrent/map"
require "view_component"
require "view_component_contrib"
require "tailwind_merge"

require "shadcn_view_component/version"
require "shadcn_view_component/icon_registry"
require "shadcn_view_component/themes"
require "shadcn_view_component/engine" if defined?(Rails::Engine)

module ShadcnViewComponent
  # `tailwind_merge` defaults to a 500-entry LRU. That is small for a page built
  # from these components: the library's own default variants already occupy
  # around a hundred entries, and a caller-computed class (`w-[#{percent}%]` in a
  # long table, say) adds one per distinct value. Once the working set of a page
  # exceeds the cache, a Rails render is the LRU's worst case — it cycles the
  # same keys every request, so the hit rate collapses and stays collapsed.
  #
  # The measured difference is roughly 0.6µs per merge on a hit against ~100µs on
  # a miss, and nothing in a stack trace would point here. So: a bigger default,
  # and a knob for apps that need more.
  DEFAULT_CACHE_SIZE = 10_000

  class << self
    attr_writer :cache_size

    def cache_size
      @cache_size ||= DEFAULT_CACHE_SIZE
    end

    # Shared TailwindMerge instance used by ApplicationViewComponent#cn.
    # This is the Ruby equivalent of shadcn's `cn()` helper
    # (clsx + tailwind-merge): later classes win over conflicting earlier ones.
    #
    # Built eagerly by the engine, because constructing it costs a few
    # milliseconds and two Puma threads racing on `||=` would each build one and
    # throw a warm cache away.
    def merger
      @merger ||= build_merger
    end

    def build_merger
      @merger = TailwindMerge::Merger.new(config: { cache_size: cache_size })
    end

    # `cn(...)` — flattens, compacts and merges Tailwind classes.
    def cn(*args)
      merger.merge(flatten_classes(args))
    end

    # Resets both the merger and the memoised component classes. For tests and
    # for `config.to_prepare` in development, where the style blocks are
    # redefined on every reload.
    def reset!
      @merger = nil
      class_cache.clear
    end

    # Compiled class strings for components rendered without caller classes,
    # which is the overwhelming majority of call sites. The result is a pure
    # function of the component class and its variants, and the style blocks are
    # static once loaded — so this both saves the merge and, more importantly,
    # keeps the library's own strings out of the LRU, leaving the whole budget to
    # what callers actually vary.
    def class_cache
      @class_cache ||= Concurrent::Map.new
    end

    private

    def flatten_classes(args)
      args.flatten.filter_map do |arg|
        case arg
        when nil, false, true then nil
        when Hash then arg.filter_map { |key, value| key.to_s if value }.join(" ")
        else arg.to_s
        end
      end.reject(&:empty?).join(" ")
    end
  end
end
