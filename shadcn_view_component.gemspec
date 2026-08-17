require_relative "lib/shadcn_view_component/version"

Gem::Specification.new do |spec|
  spec.name        = "shadcn_view_component"
  spec.version     = ShadcnViewComponent::VERSION
  spec.authors     = [ "sirion1987" ]
  spec.email       = [ "sirion1987@gmail.com" ]
  spec.homepage    = "https://github.com/gestartcloudsrl/shadcn_view_component"
  spec.summary     = "shadcn/ui components, ported 1:1 to Rails ViewComponent."
  spec.description = "A 1:1 port of the shadcn/ui component registry to Rails ViewComponent. " \
                     "Same part names, same variants, same Tailwind classes and data-slot " \
                     "attributes; Radix UI behaviour reimplemented with Stimulus."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "view_component", ">= 3.9"
  spec.add_dependency "view_component-contrib", ">= 0.2.2"
  spec.add_dependency "tailwind_merge", ">= 1.0"
end
