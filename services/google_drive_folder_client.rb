require "cgi"
require "json"
require "net/http"
require "uri"

class GoogleDriveFolderClient
  LIST_ENDPOINT = URI("https://www.googleapis.com/drive/v3/files")

  def initialize(api_key:, folder_id:)
    @api_key = api_key.to_s.strip
    @folder_id = folder_id.to_s.strip
  end

  def configured?
    !@api_key.empty? && !@folder_id.empty?
  end

  def list_photos
    raise ArgumentError, "Google Drive client is not configured" unless configured?

    files = []
    page_token = nil

    loop do
      response = get_json(
        LIST_ENDPOINT,
        {
          key: @api_key,
          q: "'#{@folder_id}' in parents and trashed = false and mimeType contains 'image/'",
          spaces: "drive",
          supportsAllDrives: "true",
          includeItemsFromAllDrives: "true",
          orderBy: "modifiedTime desc",
          pageSize: 100,
          fields: "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, imageMediaMetadata(width,height), thumbnailLink, webContentLink, webViewLink, resourceKey)",
          pageToken: page_token
        }
      )

      files.concat(Array(response.fetch("files", [])))

      page_token = response["nextPageToken"]
      break if page_token.to_s.empty?
    end

    files
      .select { |file| file["id"] && file["mimeType"].to_s.start_with?("image/") }
      .map do |file|
        {
          "id" => file["id"],
          "name" => file["name"].to_s,
          "mime_type" => file["mimeType"].to_s,
          "created_time" => file["createdTime"],
          "modified_time" => file["modifiedTime"],
          "thumbnail_link" => file["thumbnailLink"],
          "web_content_link" => file["webContentLink"],
          "web_view_link" => file["webViewLink"],
          "resource_key" => file["resourceKey"],
          "width" => file.dig("imageMediaMetadata", "width"),
          "height" => file.dig("imageMediaMetadata", "height")
        }
      end
  end

  def fetch_file(file_id)
    raise ArgumentError, "Google Drive client is not configured" unless configured?

    uri = URI("https://www.googleapis.com/drive/v3/files/#{CGI.escape(file_id)}")
    get_binary(
      uri,
      key: @api_key,
      alt: "media",
      supportsAllDrives: "true"
    )
  end

  private

  def get_json(uri, params)
    response = request(uri, params)
    JSON.parse(response.body)
  rescue JSON::ParserError => error
    raise "Google Drive returned invalid JSON: #{error.message}"
  end

  def get_binary(uri, params)
    response = request(uri, params)

    {
      status: response.code.to_i,
      body: response.body,
      content_type: response["content-type"],
      cache_control: response["cache-control"]
    }
  end

  def request(uri, params, redirect_limit: 3)
    request_uri = uri.dup
    merged_params = existing_query_params(request_uri).merge(compact_params(params).transform_keys(&:to_s))
    request_uri.query = merged_params.empty? ? nil : URI.encode_www_form(merged_params)

    response = Net::HTTP.start(request_uri.host, request_uri.port, use_ssl: request_uri.scheme == "https") do |http|
      http.request(Net::HTTP::Get.new(request_uri))
    end

    case response
    when Net::HTTPSuccess
      response
    when Net::HTTPRedirection
      raise "Too many Google Drive redirects" if redirect_limit <= 0

      redirected_uri = URI(response["location"])
      request(redirected_uri, {}, redirect_limit: redirect_limit - 1)
    else
      raise "Google Drive request failed (#{response.code}): #{response.body}"
    end
  end

  def compact_params(params)
    params.each_with_object({}) do |(key, value), memo|
      memo[key] = value unless value.nil? || value.to_s.empty?
    end
  end

  def existing_query_params(uri)
    return {} if uri.query.to_s.empty?

    URI.decode_www_form(uri.query).to_h
  rescue ArgumentError
    {}
  end
end
