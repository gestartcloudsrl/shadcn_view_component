# frozen_string_literal: true

module Shadcn
  # The parts of the InputOTP family that are just an element with a
  # `data-slot` and a fixed set of classes.
  module InputOtp
    extend Parts

    part :group, slot: "input-otp-group", classes: "flex items-center"
  end
end
