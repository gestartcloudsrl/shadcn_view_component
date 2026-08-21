# frozen_string_literal: true

# The host's own record, standing in for whatever a real application has.
#
# A plain object rather than an ActiveRecord model, because this dummy has no
# database — and that is the more useful shape anyway. What the example
# demonstrates is that a component never sees a record: the host maps its own
# objects to the hashes `EventCalendar` takes, and only the fields a cell can
# draw make that trip.
#
# Everything else — where it is, who to ring, what was said last time — stays
# here and appears when a day is opened. That is the whole of `day_url:`: the
# calendar carries what a cell can show, and the day view fetches the rest.
class Appointment
  Record = Data.define(:id, :title, :starts_at, :ends_at, :color, :assignees,
                       :location, :phone, :notes, :status)

  ASSIGNEES = [ "Ada Lovelace", "Grace Hopper", "Alan Turing", "Marie Curie" ].freeze
  PLACES = [
    [ "Acme Foods", "Via Larga 3, Bologna", "+39 051 555 0142" ],
    [ "Northwind", "Piazza Verdi 11, Bologna", "+39 051 555 0198" ],
    [ "Bellini SpA", "Via Zamboni 27, Bologna", "+39 051 555 0170" ],
    [ "Delta Clinic", "Viale Masini 8, Bologna", "+39 051 555 0126" ]
  ].freeze
  COLORS = %i[blue green amber rose].freeze
  STATUSES = %w[confirmed pencilled done].freeze

  # Seeded, so the gallery shows the same month twice and a golden means
  # something. August 2026, like every other fixture in this repo.
  def self.all
    @all ||= begin
      random = Random.new(19)

      (Date.new(2026, 8, 1)..Date.new(2026, 8, 31)).flat_map do |day|
        Array.new(random.rand(0..3)) do |index|
          place = random.rand(PLACES.size)
          starts_at = Time.zone.local(day.year, day.month, day.day, random.rand(8..16), [ 0, 30 ][random.rand(2)])

          Record.new(
            id: "#{day.iso8601}-#{index}", title: PLACES[place].first, starts_at:,
            ends_at: starts_at + [ 30, 60, 90 ][random.rand(3)].minutes,
            color: COLORS[place], assignees: ASSIGNEES.sample(random.rand(1..3), random:),
            location: PLACES[place][1], phone: PLACES[place][2],
            status: STATUSES[random.rand(STATUSES.size)],
            notes: "Last visit closed without a follow-up. Bring the spare filter."
          )
        end
      end
    end
  end

  def self.on(date) = all.select { |record| record.starts_at.to_date == date }

  # The mapping, which is the part a host writes. Six keys of a record with ten.
  def self.for_calendar
    all.map do |record|
      { id: record.id, title: record.title, starts_at: record.starts_at,
        ends_at: record.ends_at, color: record.color, assignees: record.assignees }
    end
  end
end
