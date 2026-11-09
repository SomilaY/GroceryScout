# Shoprite
Retailer.find_or_create_by!(slug: "shoprite") do |retailer|
  retailer.name = "Shoprite"
  retailer.website_url = "https://www.shoprite.co.za"
  retailer.active = true
end
