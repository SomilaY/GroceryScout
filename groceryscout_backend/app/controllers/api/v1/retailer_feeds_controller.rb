
class Api::V1::RetailerFeedsController < ApplicationController
  before_action :authenticate_retailer!

  MAX_FILE_SIZE = 5.megabytes
  MAX_CSV_ROWS = 10_000

  ALLOWED_FIELDS = %i[
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

  def create
    if params[:file].present?
      import_csv
    else
      import_json
    end
  end

  private

  def import_json
    records = params[:records]

    unless records.is_a?(Array)
      return render json: {
        error: "Records must be an array"
      }, status: :unprocessable_entity
    end

    unless records.all? { |record|
      record.is_a?(ActionController::Parameters) || record.is_a?(Hash)
    }
      return render json: {
        error: "Every record must be an object"
      }, status: :unprocessable_entity
    end

    permitted_records = records.map do |record|
      parameters = if record.is_a?(ActionController::Parameters)
        record
      else
        ActionController::Parameters.new(record)
      end

      parameters
        .permit(*ALLOWED_FIELDS)
        .to_h
        .symbolize_keys
    end

    import_records(
      permitted_records,
      source: "partner_api:#{@retailer_api_credential.id}"
    )
  end

  def import_csv
    file = params[:file]

    unless file.respond_to?(:original_filename) && file.respond_to?(:read)
      return render json: {
        error: "Invalid CSV upload"
      }, status: :unprocessable_entity
    end

    unless File.extname(file.original_filename).downcase == ".csv"
      return render json: {
        error: "Please upload a CSV file"
      }, status: :unprocessable_entity
    end

    if file.size > MAX_FILE_SIZE
      return render json: {
        error: "CSV file cannot exceed 5 MB"
      }, status: :unprocessable_entity
    end

    begin
      records = Pricing::Importers::CsvFeedParser.new(file: file).call
    rescue ArgumentError => error
      return render json: {
        error: error.message
      }, status: :unprocessable_entity
    end

    if records.length > MAX_CSV_ROWS
      return render json: {
        error: "CSV cannot contain more than 10,000 data rows"
      }, status: :unprocessable_entity
    end

    import_records(
      records,
      source: "partner_csv:#{@retailer_api_credential.id}"
    )
  end

  def import_records(records, source:)
    result = Pricing::RetailerFeedImporter.new(
      retailer_slug: @retailer_api_credential.retailer.slug,
      source: source
    ).call(records: records)

    render json: result, status: :ok
  end

  def authenticate_retailer!
    raw_token = request.headers["X-Retailer-API-Key"]

    unless raw_token.present?
      return retailer_authentication_failed
    end

    digest = RetailerApiCredential.digest_token(raw_token)

    credential = RetailerApiCredential
      .active
      .includes(:retailer)
      .find_by(token_digest: digest)

    unless credential&.active?
      return retailer_authentication_failed
    end

    @retailer_api_credential = credential
    credential.update_column(:last_used_at, Time.current)
  end

  def retailer_authentication_failed
    render json: {
      error: "Invalid or missing retailer API key"
    }, status: :unauthorized
  end
end
