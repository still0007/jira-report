require './rest_client2'
require 'addressable/uri'
require 'json'

class JIRA

  PROJECTS = {
    "OSMCLOUD" => "Oracle Social Marketing Cloud Service",
    "SRMPRT" => "SRM Portfolio"
  }

  USER_KEYS = {
    "Silu Yang" => "18c43a994729c7ea014734511cf00006",
    "Yongwen Zhao" => "18c43a9947b985290147d3639095005c",
    "Kaiyu Zhang" => "18c43a994a428e33014abe9e3ed6010a",
    "Fengzhen Cao" => "18c43a994ac48bbd014ac7e80a0d001c",
    "Baiyu Xi" => "18c43a9949bc21020149c20e19020034"
  }

  COOKIE = File.read(File.absolute_path(File.join(File.dirname(__FILE__), "cookie.txt")))
  DEFAULT_HEADER = {:Cookie=>COOKIE, :content_type=> "application/json"}

  BASE_URL = 'http://jira.oraclecorp.com/jira'
  ISSUE_SEARCH_PATH = BASE_URL + '/rest/api/2/search'
  ISSUE_DETAIL_PATH = BASE_URL + '/rest/api/2/issue'

  def self.search query
    uri = Addressable::URI.new
    uri.fragment = query

    issue_search_url = ISSUE_SEARCH_PATH + "?jql=" + uri.normalized_fragment+"&maxResults=1000"

    response = RestClient2.get(issue_search_url, DEFAULT_HEADER)
    JSON.parse(response)
  end

  def self.detail key, changelog = false
    issue_detail_url = ISSUE_DETAIL_PATH + "/#{key}"
    issue_detail_url += "/?expand=changelog" if changelog

    response = RestClient2.get(issue_detail_url, DEFAULT_HEADER)
    JSON.parse(response)
  end

  ## see: https://developer.atlassian.com/jiradev/api-reference/jira-rest-apis/jira-rest-api-tutorials/jira-rest-api-example-edit-issues
  def self.update key, hsh
    issue_update_url = ISSUE_DETAIL_PATH + "/#{key}"
    response = RestClient2.put(issue_update_url, hsh, DEFAULT_HEADER)
    return true if "" == response.body
    return false
  end
end