# frozen_string_literal: true

module Shadcn
  module Select
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # SPIKE — three ARIA shapes for a searchable select, kept only long enough
      # for axe to judge them. Delete with the rest of the spike.
      def spike_a_input_inside_listbox
        render_with_template
      end

      def spike_b_inner_list_combobox_trigger
        render_with_template
      end

      def spike_c_inner_list_plain_trigger
        render_with_template
      end
    end
  end
end
