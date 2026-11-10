module Pricing
  module Adapters
    class NormalizedFeedAdapter
      def initialize(retailer:, source:)
        @retailer = retailer
        @source = source
      end

            def import(record)
        attempts = 0

        begin
          attempts += 1
          import_once(record)
        rescue ActiveRecord::RecordNotUnique
          retry if attempts < 2

          raise
        end
      end

      private

     def import_once(record)
          raise ArgumentError, "Record must be a hash" unless record.is_a?(Hash)
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
  product = Product.find_by(barcode: barcode)

  if listing.present?
    listing_product = listing.product

    if product.present? && product.id != listing_product.id
      raise ArgumentError,
            "Retailer listing identifier belongs to a different product"
    end

    if listing_product.barcode.present? &&
       listing_product.barcode != barcode
      raise ArgumentError,
            "Retailer listing already belongs to a product with a different barcode"
    end

    listing_product.barcode = barcode
    product = listing_product
    retailer_product = listing
  else
    product ||= Product.new(barcode: barcode)

    retailer_product =
      @retailer.retailer_products.find_by(product: product) ||
      @retailer.retailer_products.new(product: product)
  end
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

                     listing_attributes = {
  product: product
}

listing_attributes[:active] = true if retailer_product.new_record?

          listing_attributes[:retailer_sku] = retailer_sku if retailer_sku.present?

          listing_attributes[:product_url] = product_url if product_url.present?

          listing_attributes[:image_url] = record[:image_url] if record[:image_url].present?

                   listing_name = record[:listing_name].presence

          if listing_name.present?
            listing_attributes[:listing_name] = listing_name
          elsif retailer_product.new_record?
            listing_attributes[:listing_name] = name
          end

          if record[:in_stock] == true || record[:in_stock] == false
            listing_attributes[:in_stock] = record[:in_stock]
          end

          retailer_product.assign_attributes(listing_attributes)

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
                "Retailer listing identifier belongs to a different product"
        end

        sku_listing || url_listing
      end
    end
  end
end