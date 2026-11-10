require "bigdecimal"

module Pricing
  class LoyaltyHubImporter
    RETAILER_MAPPINGS = {
      "checkers" => "checkers",
      "pnp" => "pick-n-pay",
      "pick-n-pay" => "pick-n-pay",
      "shoprite" => "shoprite",
      "woolworths" => "woolworths"
    }.freeze

    SOURCE = "loyalty_hub"

    def call(records:)
      provider_meta = nil

      if records.is_a?(Hash)
        envelope = records

        unless envelope.key?(:data) || envelope.key?("data")
          raise ArgumentError, "Loyalty Hub response must contain a data array"
        end

        records = envelope.key?(:data) ? envelope[:data] : envelope["data"]
        provider_meta = envelope.key?(:meta) ? envelope[:meta] : envelope["meta"]
      end

      raise ArgumentError, "Records must be an array" unless records.is_a?(Array)

      imported = []
      failed = []

      records.each_with_index do |record, index|
        begin
          retailer_slug = retailer_slug_for(record)
          normalized_record = normalize(record)

          result = RetailerFeedImporter.new(
            retailer_slug: retailer_slug,
            source: SOURCE
          ).call(records: [normalized_record])

          if result[:imported_count] == 1
            imported << result[:imported].first.merge(index: index)
          else
            error = result[:failed].first&.fetch(:error, nil) ||
                    "Product could not be imported"

            failed << { index: index, error: error }
          end
        rescue ArgumentError,
               ActiveRecord::RecordInvalid,
               ActiveRecord::RecordNotFound,
               TypeError => error
          failed << {
            index: index,
            error: error.message
          }
        end
      end

      {
        total: records.length,
        imported_count: imported.length,
        failed_count: failed.length,
        imported: imported,
        failed: failed,
        provider_meta: provider_meta
      }
    end

    private

    def retailer_slug_for(record)
      raise ArgumentError, "Record must be an object" unless record.is_a?(Hash)

      retailer = value(record, :retailer).to_s.strip.downcase
      slug = RETAILER_MAPPINGS[retailer]

      raise ArgumentError, "Unsupported Loyalty Hub retailer: #{retailer}" unless slug

      slug
    end

    def normalize(record)
      name = value(record, :name).to_s.strip
      raise ArgumentError, "Product name is required" if name.blank?

      barcode = value(record, :barcode).presence ||
                value(record, :gtin).presence

      retailer_sku = value(record, :retailer_sku).to_s.strip.presence

      if barcode.blank? && retailer_sku.blank?
        raise ArgumentError, "Barcode, GTIN or retailer SKU is required"
      end

      {
        barcode: barcode,
        retailer_sku: retailer_sku,
        name: name,
        brand: value(record, :brand),
        quantity_value: size_quantity(record),
        quantity_unit: size_unit(record),
        category: value(record, :department).presence ||
          value(record, :category),
        listing_name: name,
        image_url: value(record, :image_url),
        price_cents: price_to_cents(value(record, :price)),
        currency: value(record, :currency).presence || "ZAR",
in_stock: value(record, :in_stock),
observed_at: observed_at(record)
      }
    end

    def price_to_cents(price)
      raise ArgumentError, "Price is required" if price.blank?

      amount = BigDecimal(price.to_s)

      raise ArgumentError, "Price must be greater than zero" unless amount.positive?

      (amount * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    rescue ArgumentError
      raise
    rescue StandardError
      raise ArgumentError, "Price must be a valid number"
    end

    def observed_at(record)
      timestamp = value(record, :last_seen_at)

      raise ArgumentError, "Last seen timestamp is required" if timestamp.blank?

      Time.zone.parse(timestamp.to_s) ||
        raise(ArgumentError, "Last seen timestamp is invalid")
    rescue ArgumentError
      raise
    rescue StandardError
      raise ArgumentError, "Last seen timestamp is invalid"
    end

    def size_quantity(record)
      size = value(record, :size)
      return unless size.is_a?(Hash)

      value(size, :quantity)
    end

    def size_unit(record)
      size = value(record, :size)
      return unless size.is_a?(Hash)

      value(size, :unit)
    end

   def value(hash, key)
  hash.key?(key) ? hash[key] : hash[key.to_s]
end
  end
end
