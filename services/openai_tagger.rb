require "json"
require "net/http"
require "uri"

class OpenAITagger
  API_ENDPOINT = URI("https://api.openai.com/v1/responses")
  DEFAULT_MODEL = "gpt-5.6-luna"

  def initialize(api_key:, model: DEFAULT_MODEL)
    @api_key = api_key.to_s.strip
    @model = model.to_s.strip.empty? ? DEFAULT_MODEL : model.to_s.strip
  end

  def configured?
    !@api_key.empty?
  end

  def tag_photo(photo)
    raise ArgumentError, "OpenAI tagger is not configured" unless configured?

    image_url = photo["thumbnail_link"].to_s.strip
    raise ArgumentError, "Photo thumbnail is missing" if image_url.empty?

    response = post_json(build_payload(image_url))
    response_text = extract_response_text(response)

    JSON.parse(response_text)
  rescue JSON::ParserError => error
    raise "OpenAI returned invalid JSON tags: #{error.message}"
  end

  private

  def build_payload(image_url)
    {
      model: @model,
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: "Analyze this photo for a collectible photo app. Return only short factual visual tags. Do not guess identity, age, ethnicity, health, or other sensitive traits. Output JSON matching the schema."
            },
            {
              type: "input_image",
              image_url: image_url,
              detail: "low"
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "photo_tags",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              short_tags: {
                type: "array",
                items: { type: "string" },
                minItems: 4,
                maxItems: 10
              },
              mood: {
                type: "array",
                items: { type: "string" },
                maxItems: 3
              },
              setting: {
                type: "array",
                items: { type: "string" },
                maxItems: 3
              },
              style: {
                type: "array",
                items: { type: "string" },
                maxItems: 3
              },
              objects: {
                type: "array",
                items: { type: "string" },
                maxItems: 6
              }
            },
            required: %w[short_tags mood setting style objects]
          }
        }
      }
    }
  end

  def post_json(payload)
    request = Net::HTTP::Post.new(API_ENDPOINT)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(API_ENDPOINT.host, API_ENDPOINT.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "OpenAI tagging failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => error
    raise "OpenAI returned invalid response JSON: #{error.message}"
  end

  def extract_response_text(response)
    return response["output_text"] if response["output_text"].to_s.strip != ""

    output = Array(response["output"])
    output.each do |item|
      Array(item["content"]).each do |content|
        text = content["text"].to_s
        return text if text.strip != ""
      end
    end

    raise "OpenAI response did not include output text"
  end
end
