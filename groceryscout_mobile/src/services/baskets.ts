
import * as SecureStore from 'expo-secure-store';
import { apiRequest } from './api';

const BASKET_ID_KEY = 'groceryscout_basket_id';

export interface BasketItem {
  id: number;
  product_id: number;
  product_name: string;
  quantity: number;
}

export interface Basket {
  id: number;
  name: string;
  items: BasketItem[];
}

export interface BasketComparison {
  retailer: string;
  complete: boolean;
  total_cents: number | null;
  items: {
    product_name: string;
    quantity: number;
    unit_price_cents: number;
    line_total_cents: number;
    observed_at: string;
    fresh: boolean;
    status: string;
    age_in_hours: number;
  }[];
  missing_items: string[];
  stale_items: {
    product_name: string;
    quantity: number;
    last_price_cents: number;
    observed_at: string;
    fresh: boolean;
    status: string;
    age_in_hours: number;
  }[];
}

export interface BasketComparisonResponse {
  basket_id: number;
  basket_name: string;
  comparisons: BasketComparison[];
  cheapest_retailer: {
    name: string;
    total_cents: number;
  } | null;
}

interface BasketResponse {
  message?: string;
  basket?: Basket;
}

interface BasketItemResponse {
  message: string;
  item: BasketItem;
}

export async function createBasket(name = 'My Basket') {
  const response = await apiRequest<BasketResponse>('/api/v1/baskets', {
    method: 'POST',
    body: JSON.stringify({ basket: { name } }),
  });

  if (!response.basket) {
    throw new Error('The basket could not be created.');
  }

  await SecureStore.setItemAsync(
    BASKET_ID_KEY,
    response.basket.id.toString()
  );

  return response.basket;
}

export async function getOrCreateBasket(): Promise<Basket> {
  const savedId = await SecureStore.getItemAsync(BASKET_ID_KEY);

  if (savedId) {
    try {
      return await getBasket(Number(savedId));
    } catch {
      await SecureStore.deleteItemAsync(BASKET_ID_KEY);
    }
  }

  return createBasket();
}

export async function getBasket(basketId: number) {
  return apiRequest<Basket>(`/api/v1/baskets/${basketId}`);
}

export async function addBasketItem(
  basketId: number,
  productId: number,
  quantity = 1
) {
  return apiRequest<BasketItemResponse>(
    `/api/v1/baskets/${basketId}/items`,
    {
      method: 'POST',
      body: JSON.stringify({
        product_id: productId,
        quantity,
      }),
    }
  );
}

export async function updateBasketItem(
  basketId: number,
  itemId: number,
  quantity: number
) {
  return apiRequest<BasketItemResponse>(
    `/api/v1/baskets/${basketId}/items/${itemId}`,
    {
      method: 'PATCH',
      body: JSON.stringify({ quantity }),
    }
  );
}

export async function removeBasketItem(
  basketId: number,
  itemId: number
) {
  return apiRequest<{ message: string }>(
    `/api/v1/baskets/${basketId}/items/${itemId}`,
    {
      method: 'DELETE',
    }
  );
}

export async function compareBasket(basketId: number) {
  return apiRequest<BasketComparisonResponse>(
    `/api/v1/baskets/${basketId}/compare`
  );
}
