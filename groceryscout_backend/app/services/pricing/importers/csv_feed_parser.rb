require "csv"

module Pricing
  module Importers
    class CsvFeedParser
      REQUIRED_HEADERS = %w[
        name
        price_cents
      ].freeze

      ALLOWED_HEADERS = %w[
        barcode
        name
        brand
        quantity_value
        quantity_unit
        category
        retailer_sku
        listing_name
        product_url
        image_url
        price_cents
        currency
        observed_at
      ].freeze

      def initialize(file:)
        @file = file
      end

      def call
        csv = CSV.parse(@file.read, headers: true)

        headers = Array(csv.headers).map do |header|
          header&.strip&.downcase
        end

        if headers.any?(&:blank?)
          raise ArgumentError, "CSV contains an empty column name"
        end

        if headers.uniq.length != headers.length
          raise ArgumentError, "CSV contains duplicate column names"
        end

        missing_headers = REQUIRED_HEADERS - headers

        if missing_headers.any?
          raise ArgumentError,
                "Missing required columns: #{missing_headers.join(', ')}"
        end

        unknown_headers = headers - ALLOWED_HEADERS

        if unknown_headers.any?
          raise ArgumentError,
                "Unsupported columns: #{unknown_headers.join(', ')}"
        end

        csv.map.with_index do |row, index|
          record = headers.each_with_index.each_with_object({}) do |(header, column_index), result|
            result[header.to_sym] = row.fields[column_index]&.strip
          end

          if record[:name].blank?
            raise ArgumentError,
                  "Row #{index + 2}: Product name is required"
          end

          if record[:price_cents].blank?
            raise ArgumentError,
                  "Row #{index + 2}: Price is required"
          end

          if record[:barcode].blank? &&
             record[:retailer_sku].blank? &&
             record[:product_url].blank?
            raise ArgumentError,
                  "Row #{index + 2}: Barcode, retailer_sku or product_url is required"
          end

          record
        end
      rescue CSV::MalformedCSVError
        raise ArgumentError, "Invalid CSV file"
      end
    end
  end
end