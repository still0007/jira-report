module Weekdays
  def self.duration date_from, date_to
    only_weekdays(date_from..date_to)
  end

  protected
  def self.only_weekdays(range)
    range.select { |d| (1..5).include?(d.wday) }.size
  end
end