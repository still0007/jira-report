require './jira'
require './lib/weekdays'
require './lib/file_serializer'
require 'pp'
require 'date'
require 'erb'

class Report

  FROM_DATE = Date.parse('2015-4-17')

  DEVELOPERS = {
    "Silu Yang" => 3,
    "Yongwen Zhao" => 5,
    "Kaiyu Zhang" => 1,
    "Fengzhen Cao" => 1,
    "Baiyu Xi" => 1
  }

  LABELS = ['nls_code_defect', 'nls_incorrect_I18N', 'nls_format_issue', 'nls_cannot_reproduce', 'nls_not_a_bug', 'nls_other']

  def self.is_done? status_name
    status = status_name.split(" ")[0].to_i
    status == 39 or status == 31 or status == 32 or status > 60
  end

  def self.goal weekdays, factor
    factor == 1 ? [weekdays*factor, 12].min : weekdays*factor
  end

  def self.query_by_developers project
    grand_total = 0
    statistics = {}
    DEVELOPERS.each_key do |name|
      query = "project='#{project}' AND labels in (#{LABELS.join(',')}) and assignee = '#{name}'"
      result = JIRA.search(query)

      statistics[name] = {}
      statistics[name]['total'] = result["total"]
      statistics[name]['statuses'] = {}
      result["issues"].each do |issue|
        issue_key = issue['key']
        status = is_done?(issue['fields']['status']['name']) ? 'done' : 'not_done'

        statistics[name]['statuses'][status] = {'total'=>0, 'issues'=>[]} unless statistics[name]['statuses'][status]
        statistics[name]['statuses'][status]['total'] += 1
        statistics[name]['statuses'][status]['issues'] << issue_key
      end
      grand_total += result["total"]
    end

    [grand_total, statistics]
  end

  def self.generate_chart_data statistics
    chart_data = []

    done_total = 0
    not_done_total = 0
    weekdays = Weekdays.duration(FROM_DATE, Date::today)
    statistics.each_key do |name|
      factor = DEVELOPERS[name]

      chart_data << "['#{name}', #{goal(weekdays, factor)}, #{statistics[name]['statuses']['done']['total']}, #{statistics[name]['statuses']['not_done'].nil? ? 0 : statistics[name]['statuses']['not_done']['total']}]"
      done_total += statistics[name]['statuses']['done']['total']
      not_done_total += statistics[name]['statuses']['not_done']['total'] unless statistics[name]['statuses']['not_done'].nil?
    end
    chart_data << "['Total', #{[weekdays*13,154].min}, #{done_total}, #{not_done_total}]"
    chart_data
  end

  def self.generate_daily_report statistics
    chart_data = Report.generate_chart_data(statistics).join(',');
    FileSerializer.save("history/#{Date::today.strftime('%Y%m%d')}", chart_data)

    data = {}
    daily = []
    from_to = "#{Report::FROM_DATE.strftime('%m/%d/%Y %A')} - #{Date::today.strftime('%m/%d/%Y %A')}"
    Dir.glob("history/*").sort.each do |f|
      date = f.sub("history/", '')
      data[date] = FileSerializer.load(f).gsub(/, \d*\]/, ']')
      sum = 0
      data[date].split("],[").slice(0, 5).each {|x| sum += x.split(',')[2].to_i}
      daily << [Date.parse(date).strftime('%m/%d/%Y'), sum]
    end

    daily.insert(0, ['Date', 'Dev Done'])

    template = ERB.new(File.new("report/template.html.erb").read, nil, '%')
    File.open("report/all.html", "w+") do |f|
      f.write(template.result(binding))
    end
  end
end

grand_total, statistics = Report.query_by_developers(JIRA::PROJECTS["OSMCLOUD"])
Report.generate_daily_report(statistics)
