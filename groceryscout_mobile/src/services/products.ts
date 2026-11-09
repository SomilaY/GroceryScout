import { apiRequest } from './api';

export interface RetailerPrice {
  retailer: string;
  image_url: string | null;
  product_url: string | null;
  price: number;
  currency: string;
  observed_at: string;
  fresh: boolean;
  status: 'fresh' | 'stale' | string;
  age_in_hours: number;
}

export interface Product {
  id: number;
  name: string;
  brand: string | null;
  quantity: string | null;
  unit: string | null;
  category: string | null;
  prices: RetailerPrice[];
}

interface ProductsResponse {
  products: Product[];
  pagination: {
    current_page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
}

export async function fetchProducts(search = '') {
  const query = search
    ? `?search=${encodeURIComponent(search)}`
    : '';

  return apiRequest<ProductsResponse>(
    `/api/v1/products${query}`
  );
}

export async function fetchProduct(id: number): Promise<Product> {
  const response = await apiRequest<{ product: Product }>(
    `/api/v1/products/${id}`
  );

  return response.product;
}

export interface PriceHistoryPoint {
  price_cents: number;
  price: number;
  currency: string;
  observed_at: string;
}

export interface RetailerPriceHistory {
  retailer: string;
  prices: PriceHistoryPoint[];
}

export interface PriceHistoryResponse {
  product: {
    id: number;
    name: string;
    brand: string | null;
  };
  period_days: number;
  start_date: string;
  end_date: string;
  retailers: RetailerPriceHistory[];
}

export async function fetchPriceHistory(
  id: number,
  days = 30
): Promise<PriceHistoryResponse> {
  return apiRequest<PriceHistoryResponse>(
    `/api/v1/products/${id}/price_history?days=${days}`
  );
}