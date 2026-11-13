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

  # What a host does with `preferences: :host`, kept to its shape: take the
  # fields the dialog sent, keep them, and send the person back with a
  # `303`. A host keeps them on its user and redirects to its calendar; this
  # one has neither, so it keeps them in the session and shows them.
  #
  # The token is recorded rather than verified. Lookbook renders a preview in a
  # nested controller whose session is never written back, so the token the
  # dialog carries matches a session the browser does not have — a fact about
  # the gallery, not about the form, and a host renders its calendar in its
  # own request. What the spec needs to know is that the token rode along.
  skip_forgery_protection only: :save_preferences

  def save_preferences
    session[:calendar_preferences] = params.expect(preferences: %i[period view showing group shape max_chips]).to_h
    session[:calendar_preferences_token] = request.request_parameters.key?("authenticity_token")
    redirect_to "/calendar/preferences", status: :see_other
  end

  def preferences
    @preferences = session[:calendar_preferences] || {}
    @token = session[:calendar_preferences_token]
  end
end
