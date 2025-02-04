class CalendarPlan < ApplicationRecord
  belongs_to :user
  belongs_to :recipe

  validates :date, presence: true
  validates :meal_time, presence: true, inclusion: { in: [ "morning", "afternoon", "evening" ] }
end
