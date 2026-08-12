# frozen_string_literal: true

module Shadcn
  module InputOtp
    module Separator
      # InputOTPSeparator — a minus between two groups. Upstream gives it a role
      # and no classes at all.
      class Component < ApplicationViewComponent
        slot_name :"input-otp-separator"

        def element_attributes(**defaults)
          super(**{ role: "separator" }.merge(defaults))
        end

        def call
          render_element(body: render(Icon::Component.new("minus")))
        end
      end
    end
  end
end
