require './lib/jira'
require './lib/weekdays'
require './lib/file_serializer'
require 'pp'
require 'date'
require 'erb'
require 'open-uri'

class Detail

  LABELS = ['nls_code_defect', 'nls_incorrect_I18N', 'nls_format_issue', 'nls_cannot_reproduce', 'nls_not_a_bug', 'nls_other']

  DEVELOPERS = {
      "Silu Yang" => 3,
      "Yongwen Zhao" => 5,
      "Kaiyu Zhang" => 1,
      "Fengzhen Cao" => 1,
      "Baiyu Xi" => 1
  }

  def self.show_undownload_avatars avatars
    avatars.each_key do |name|
      file_name = "images/#{name.gsub(/ /, '').downcase}.png"
      unless File.exist?(file_name)
        puts name
        puts avatars[name]
      end
    end
  end

  # "OSMCLOUD-1804" => {"assignee"=>"Yongwen Zhao", "status"=>"39 - Approved, waiting for codeline to open", "labels"=>["dev_done", "nls_code_defect"]}
  def self.all_nls_issues project
    issues = {}
    avatars = {}

    LABELS.each do |label|
      query = "project='#{project}' AND labels = #{label}"
      results = JIRA.search(query)['issues']

      results.each do |result|
        issues[result["key"]] = {
            "summary" => result['fields']['summary'],
            "assignee" => result['fields']['assignee']['displayName'],
            "status" => result['fields']['status']['name'],
            # "components" => issue['fields']['components'][0]['name'],   #to be refactored
            "labels" => result['fields']['labels'].select{|x| x =='dev_done' or /^nls_/.match(x) }
        }
        avatars[result['fields']['assignee']['displayName']] = result['fields']['assignee']['avatarUrls']['16x16']
      end
    end

    show_undownload_avatars(avatars)

    issues
  end

  def self.statistics_by_status issues
    result = {}
    issues.each_key do |issue_key|
      status = issues[issue_key]['status']
      summary = issues[issue_key]['summary']
      labels = issues[issue_key]['labels']
      assignee = issues[issue_key]['assignee']

      result[status] = {'total' => 0, 'issues' => []} if result[status].nil?
      result[status]['total'] += 1
      result[status]['issues'] << { "key" => issue_key, "summary" => summary, "labels" => labels, "assignee" => assignee}
    end

    result
  end

  def self.statistics_by_developer issues
    result = {}
    issues.each_key do |issue_key|
      status = issues[issue_key]['status']
      assignee = issues[issue_key]['assignee']
      summary = issues[issue_key]['summary']
      labels = issues[issue_key]['labels']

      next unless DEVELOPERS.keys.include?(assignee)

      result[assignee] = {} if result[assignee].nil?
      result[assignee][status] = [] if result[assignee][status].nil?
      result[assignee][status] << { "key" => issue_key, "summary" => summary, "labels" => labels }
    end

    result
  end

  def self.statistics_not_assigned issues
    result = {}
    issues.each_key do |issue_key|
      assignee = issues[issue_key]['assignee']
      summary = issues[issue_key]['summary']
      labels = issues[issue_key]['labels'].select{|x| /^nls_/.match(x) }.join(",")

      next if DEVELOPERS.keys.include?(assignee)

      result[labels] = [] if result[labels].nil?
      result[labels] << { "key" => issue_key, "summary" => summary, "labels" => labels }
    end

    result
  end
end

def add_labels_back
  project = JIRA::PROJECTS["OSMCLOUD"]

  query = "project='#{project}' AND labels = 'for_review_tabs_shop'"
  results = JIRA.search(query)['issues']

  changelog = {}

  results.each do |result|
    key = result["key"]
    histories = JIRA.detail(key, true)['changelog']['histories']
    items = histories.last['items']
    labels = []
    items.each do |item|
      labels.concat(item['fromString'].split(" ")) if item['field']=='labels' and !item['fromString'].nil?
    end

    changelog[key] = labels
  end

  changelog.each_key do |key|
    actions = []
    changelog[key].each {|label| actions << {"add" => label}}
    hsh = { "update"=> { "labels"=> actions } }.to_json

    JIRA.update(key, hsh)

    puts "******* Added labels #{changelog[key]} for #{key}"
  end
end

def generate_detailed_summary
  issues = Detail.all_nls_issues(JIRA::PROJECTS["OSMCLOUD"])

  total = issues.keys.count
  statistics_by_status =  Detail.statistics_by_status(issues)
  statistics_by_developer = Detail.statistics_by_developer(issues)
  statistics_not_assigned = Detail.statistics_not_assigned(issues)

  template = ERB.new(File.new("report/detail.template.html.erb").read, nil, '%')
  File.open("report/detail.html", "w+") do |f|
    f.write(template.result(binding))
  end
end

generate_detailed_summary
