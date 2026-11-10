
Rails.application.routes.draw do
  get "up", to: proc { [200, { "Content-Type" => "text/plain" }, ["OK"]] }

  namespace :api do
    namespace :v1 do
      post "register", to: "registrations#create"
      post "login", to: "sessions#create"
      post "password/forgot", to: "passwords#forgot"
      patch "password/reset", to: "passwords#reset"
      post "refresh", to: "tokens#refresh"
      delete "logout", to: "sessions#destroy"

      resources :products, only: [:index, :show] do
        member do
          get :price_history
        end
      end

      get "categories", to: "categories#index"
      post "retailer_feeds/import", to: "retailer_feeds#create"

      resources :baskets, only: [:create, :show] do
        member do
          get :compare
        end

        resources :items,
                  controller: "basket_items",
                  only: [:create, :update, :destroy]
      end
    end
  end
end
