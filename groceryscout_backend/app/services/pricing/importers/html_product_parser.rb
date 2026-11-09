
require "nokogiri"
require "bigdecimal"
require "json"

module Pricing
  module Importers
    class HtmlProductParser
      UNIT_CONVERSIONS = {
        "kg" => ["kg", 1],
        "g" => ["kg", 0.001],
        "gram" => ["kg", 0.001],
        "grams" => ["kg", 0.001],
        "mg" => ["kg", 0.000001],
        "l" => ["l", 1],
        "litre" => ["l", 1],
        "litres" => ["l", 1],
        "liter" => ["l", 1],
        "liters" => ["l", 1],
        "ml" => ["l", 0.001]
      }.freeze

      def initialize(html:)
        @html = html
      end

      def call
        document = Nokogiri::HTML(@html)
        json_ld = extract_json_ld_product(document)

        quantity = extract_quantity(document, json_ld)

        {
          name: extract_name(document, json_ld),
          price_cents: extract_price(document, json_ld),
          quantity_value: quantity&.first,
          quantity_unit: quantity&.last
        }
      end

      private

      def extract_json_ld_product(document)
        document.css('script[type="application/ld+json"]').each do |script|
          data = JSON.parse(script.text)
          products = find_products(data)

          return products.first if products.any?
        rescue JSON::ParserError
          next
        end

        nil
      end

      def find_products(data)
        case data
        when Array
          data.flat_map { |item| find_products(item) }
        when Hash
          type = data["@type"]

          products =
            if type == "Product" || (type.is_a?(Array) && type.include?("Product"))
              [data]
            else
              []
            end

          products + data.values.flat_map { |value| find_products(value) }
        else
          []
        end
      end

      def extract_name(document, json_ld)
        value =
          json_ld&.dig("name") ||
          document.at_css('meta[property="og:title"]')&.[]("content") ||
          document.at_css("h1")&.text

        value&.strip.presence
      end

   def extract_price(document, json_ld)
  offers = json_ld&.dig("offers")
  offers = [offers] unless offers.is_a?(Array)

  json_ld_price = offers&.filter_map do |offer|
    next unless offer.is_a?(Hash)

    price = parse_price_cents(offer["price"])
    price if price&.positive?
  end&.first

  return json_ld_price if json_ld_price

  fallback_values = [
    document.at_css('meta[property="product:price:amount"]')&.[]("content"),
    document.at_css('[itemprop="price"]')&.[]("content"),
    document.at_css('[itemprop="price"]')&.text
  ]

  fallback_values.each do |value|
    price = parse_price_cents(value)
    return price if price&.positive?
  end

  nil
end

def parse_price_cents(value)
  return if value.blank?

  normalized = value.to_s.gsub(/[^\d,.]/, "")
  return if normalized.blank?

  normalized = normalized.delete(",") if normalized.include?(".")
  normalized = normalized.tr(",", ".")

  return unless normalized.match?(/\A\d+(?:\.\d{1,2})?\z/)

  (BigDecimal(normalized) * 100).round.to_i
rescue ArgumentError
  nil
end

     def extract_quantity(document, json_ld)
  structured_quantity = extract_structured_quantity(
    json_ld&.dig("weight")
  )

  return structured_quantity if structured_quantity

  text = [
    json_ld&.dig("weight"),
    json_ld&.dig("name"),
    product_text(document)
  ].compact.join(" ")

  multipack = text.match(
    /(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(kg|g|mg|litres?|liters?|l|ml|grams?)\b/i
  )

  if multipack
    count = BigDecimal(multipack[1].tr(",", "."))
    size = BigDecimal(multipack[2].tr(",", "."))
    unit = multipack[3].downcase

    standard_unit, multiplier = UNIT_CONVERSIONS.fetch(unit)

    total = count * size * BigDecimal(multiplier.to_s)

    return [total.to_f, standard_unit]
  end

  match = text.match(
    /(\d+(?:[.,]\d+)?)\s*(kg|g|mg|litres?|liters?|l|ml|grams?)\b/i
  )

  return unless match

  value = BigDecimal(match[1].tr(",", "."))
  unit = match[2].downcase
  standard_unit, multiplier = UNIT_CONVERSIONS.fetch(unit)

  [(value * BigDecimal(multiplier.to_s)).to_f, standard_unit]
end

def extract_structured_quantity(weight)
  return unless weight.is_a?(Hash)

  value = weight["value"]
  unit = weight["unitCode"] || weight["unitText"]

  return if value.blank? || unit.blank?

  unit = unit.to_s.downcase

  unit = {
    "ltr" => "l",
    "l" => "l",
    "mlt" => "ml",
    "kgm" => "kg",
    "grm" => "g",
    "mgm" => "mg"
  }.fetch(unit, unit)

  conversion = UNIT_CONVERSIONS[unit]

  return unless conversion

  standard_unit, multiplier = conversion

  quantity = BigDecimal(value.to_s) * BigDecimal(multiplier.to_s)

  [quantity.to_f, standard_unit]
rescue ArgumentError
  nil
end

      def product_text(document)
        [
          document.at_css('meta[property="og:title"]')&.[]("content"),
          document.at_css("h1")&.text,
          document.at_css('meta[name="description"]')&.[]("content")
        ].compact.join(" ")
      end
    end
  end
end
