# frozen_string_literal: true

require "spec_helper"

# Golden snapshots of the rendered HTML for every preview.
#
# This is the guarantee `parity_spec.rb` cannot give. That spec compares sets of
# class tokens per family, so it sees a class that was dropped or mistyped — but
# not one that moved to the wrong part, or landed under the wrong variant, or an
# attribute that changed. A diff of the actual output sees all of it.
#
# Regenerate after an intentional change, then read the diff before committing:
#
#     SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
#
RSpec.describe "rendered output snapshots" do
  fixtures = Pathname(__dir__).join("fixtures/snapshots")
  previews = Pathname(__dir__).join("../app/components/shadcn")

  # One element per line, so a diff points at the element that changed instead
  # of at one enormous line. Generated ids differ per render and say nothing
  # about parity, so they are flattened first.
  def self.normalize(html)
    html.gsub(/\b(shadcn-(?:checkbox|switch)-)[0-9a-f]{8}\b/, '\1x')
        .gsub(/\s+/, " ")
        .gsub(/\s*</, "\n<")
        .strip + "\n"
  end

  def normalize(html) = self.class.normalize(html)

  templates = Dir[previews.join("*/previews/*.html.erb")].sort

  it "has a preview to snapshot for nearly every family" do
    families = templates.map { |path| Pathname(path).parent.parent.basename.to_s }.uniq
    all = Dir[previews.join("*/component.rb")].map { |path| Pathname(path).parent.basename.to_s }

    # `icon` is the only part with no preview of its own — it only ever appears
    # inside another component.
    expect(all - families).to eq(%w[icon])
  end

  templates.each do |template|
    name = Pathname(template).relative_path_from(previews).to_s.sub("/previews/", "-").sub(".html.erb", "")
    fixture = fixtures.join("#{name}.html")

    it "renders #{name} unchanged" do
      rendered = normalize(ApplicationController.renderer.render(inline: File.read(template)))

      if ENV["SNAPSHOTS"] == "overwrite"
        fixtures.mkpath
        fixture.write(rendered)
      end

      expect(fixture).to exist,
                         "no snapshot for #{name}; run SNAPSHOTS=overwrite bundle exec rspec"
      expect(rendered).to eq(fixture.read)
    end
  end
end
