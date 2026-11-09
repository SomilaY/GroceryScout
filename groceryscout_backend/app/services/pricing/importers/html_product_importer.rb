module Pricing
  module Importers
    class HtmlProductImporter
      ADAPTERS = {
        "shoprite" => Adapters::ShopriteAdapter,
        "checkers" => Adapters::CheckersAdapter,
        "pick-n-pay" => Adapters::PickNPayAdapter,
        "woolworths" => Adapters::WoolworthsAdapter
      }.freeze

      def initialize(retailer_slug:, source: nil)
        adapter_class = ADAPTERS[retailer_slug.to_s]

        raise ArgumentError, "Unsupported retailer" unless adapter_class

        @adapter = adapter_class.new(source: source || "#{retailer_slug}_html")
      end

      def call(html:, product_url:)
        raise ArgumentError, "HTML is required" if html.blank?
        raise ArgumentError, "Product URL is required" if product_url.blank?

        record = HtmlProductParser.new(html: html).call

        if record[:name].blank?
          raise ArgumentError, "Product name could not be extracted"
        end

        if record[:price_cents].blank?
          raise ArgumentError, "Product price could not be extracted"
        end

        record[:product_url] = product_url
        record[:listing_name] = record[:name]

        @adapter.import(record)
      end
    end
  end
end