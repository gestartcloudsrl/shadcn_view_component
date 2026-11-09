# frozen_string_literal: true

# The server half of the event calendar's `day_url:` example. With Turbo the
# response lands in the frame the agenda became; without it, it is a page. The
# link degrades because it is a link.
class CalendarController < ApplicationController
  def day
    @date = Date.parse(params[:date])
    @appointments = Appointment.on(@date)
  end

  # The page an agenda row links to. Only the id is read: what an event is
  # called is the whole of what this example needs to show.
  def event
    @id = params[:id]
  end
end
