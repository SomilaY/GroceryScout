namespace :retailer_credentials do
  desc "Issue an API credential for a retailer"
  task :issue, [:retailer_slug] => :environment do |_task, args|
    retailer_slug = args[:retailer_slug].to_s

    if retailer_slug.blank?
      abort "Usage: bin/rails retailer_credentials:issue[checkers]"
    end

    retailer = Retailer.find_by(slug: retailer_slug)

    abort "Retailer not found" unless retailer

    begin
      credential, raw_token =
        RetailerApiCredential.issue_for!(retailer: retailer)

      puts ""
      puts "Retailer API credential created successfully."
      puts "Retailer: #{retailer.name}"
      puts "Credential ID: #{credential.id}"
      puts ""
      puts "API KEY (copy it now; it cannot be retrieved later):"
      puts raw_token
      puts ""
    rescue ArgumentError => error
      abort error.message
    end
  end

  desc "Revoke a retailer API credential"
  task :revoke, [:credential_id] => :environment do |_task, args|
    credential_id = args[:credential_id].to_s

    if credential_id.blank?
      abort "Usage: bin/rails retailer_credentials:revoke[1]"
    end

    credential = RetailerApiCredential.find_by(id: credential_id)

    abort "Credential not found" unless credential

    credential.revoke!

    puts "Credential #{credential.id} revoked successfully."
  end
end