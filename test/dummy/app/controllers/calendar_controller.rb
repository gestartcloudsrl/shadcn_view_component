# frozen_string_literal: true

# The server half of the event calendar's `day_url:` example. With Turbo the
# response lands in the frame the agenda became; without it, it is a page. The
# link degrades because it is a link.
class CalendarController < ApplicationController
  def day
    @date = Date.parse(params[:date])
    @appointments = Appointment.on(@date)
  end
end
