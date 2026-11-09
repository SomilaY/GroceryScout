module Pricing
  module Adapters
    class NormalizedFeedAdapter
      def initialize(retailer:, source:)
        @retailer = retailer
        @source = source
      end

      def import(record)
        barcode = record[:barcode].to_s.strip.presence
        name = record[:name].to_s.strip
        price_cents = record[:price_cents]
        product_url = record[:product_url].to_s.strip.presence
        retailer_sku = record[:retailer_sku].to_s.strip.presence

        raise ArgumentError, "Product name is required" if name.blank?
        raise ArgumentError, "Price is required" if price_cents.blank?

        if barcode.blank? && product_url.blank? && retailer_sku.blank?
          raise ArgumentError,
                "Barcode, product URL or retailer SKU is required"
        end

        ActiveRecord::Base.transaction do
          listing = find_listing_by_identifiers(
            retailer_sku: retailer_sku,
            product_url: product_url
          )

          if barcode.present?
            product = Product.find_or_initialize_by(barcode: barcode)

            if listing.present? && listing.product_id != product.id
              raise ArgumentError,
                    "Retailer listing identifier belongs to a different product"
            end

            retailer_product =
              listing || @retailer.retailer_products.new(product: product)
          else
            retailer_product = listing
            product = listing&.product || Product.new

            retailer_product ||= @retailer.retailer_products.new(
              product: product
            )
          end

          shared_attributes = {
            name: name,
            brand: record[:brand],
            quantity_value: record[:quantity_value],
            quantity_unit: record[:quantity_unit],
            category: record[:category]
          }

          shared_attributes.each do |attribute, value|
            if product.new_record? || product[attribute].blank?
              product[attribute] = value if value.present?
            end
          end

          product.save!

          retailer_product.assign_attributes(
            product: product,
            retailer_sku: retailer_sku,
            listing_name: record[:listing_name].presence || name,
            product_url: product_url,
            image_url: record[:image_url],
            active: true
          )

          retailer_product.save!

          PriceIngestionService.new(
            retailer_product_id: retailer_product.id,
            price_cents: price_cents,
            source: @source,
            observed_at: record[:observed_at] || Time.current,
            currency: record[:currency] || "ZAR"
          ).call

          retailer_product
        end
      end

      private

      def find_listing_by_identifiers(retailer_sku:, product_url:)
        sku_listing =
          if retailer_sku.present?
            @retailer.retailer_products.find_by(
              retailer_sku: retailer_sku
            )
          end

        url_listing =
          if product_url.present?
            @retailer.retailer_products.find_by(
              product_url: product_url
            )
          end

        if sku_listing.present? &&
           url_listing.present? &&
           sku_listing.id != url_listing.id
          raise ArgumentError,
                "Retailer SKU and product URL identify different listings"
        end

        sku_listing || url_listing
      end
    end
  end
end