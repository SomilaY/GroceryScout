import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  Pressable,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';
import { fetchProducts } from '@/services/products';

interface ExploreProduct {
  id: number;
  name: string;
  brand: string | null;
  detail: string;
  price: number | null;
  store: string;
  category: string;
  fresh: boolean;
  emoji: string;
  prices: {
    retailer: string;
    price: number;
    fresh: boolean;
  }[];
  savings: number | null;
  dealStore: string | null;
}

const categoryEmoji: Record<string, string> = {
  Dairy: '🥛',
  Bakery: '🍞',
  Pantry: '🛒',
  'Fresh produce': '🥑',
};

const categories = ['All', 'Dairy', 'Bakery', 'Pantry'];

const stores = [
  'All stores',
  'Checkers',
  'Shoprite',
  'Pick n Pay',
  'Woolworths',
];

export default function ExploreScreen() {
  const router = useRouter();
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All');
  const [store, setStore] = useState('All stores');
  const [sortBy, setSortBy] = useState<
  'price' | 'savings' | 'name'
>('price');

  const [products, setProducts] = useState<ExploreProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadProducts() {
      try {
        setLoading(true);
        setError('');

        const response = await fetchProducts();

        const mappedProducts: ExploreProduct[] =
  response.products.map((product) => {
    const prices = product.prices.map((item) => ({
      retailer: item.retailer,
      price: item.price,
      fresh: item.fresh,
    }));

    const freshPrices = prices.filter((item) => item.fresh);

    const availablePrices = freshPrices.length > 0
      ? freshPrices
      : prices;

    const cheapestPrice = [...availablePrices].sort(
      (a, b) => a.price - b.price
    )[0];

    const mostExpensivePrice = freshPrices.length > 1
      ? Math.max(...freshPrices.map((item) => item.price))
      : null;

    const savings =
      cheapestPrice && mostExpensivePrice !== null
        ? Math.max(0, mostExpensivePrice - cheapestPrice.price)
        : null;

    return {
      id: product.id,
      name: product.name,
      brand: product.brand,
      detail:
        product.quantity && product.unit
          ? `${product.quantity} ${product.unit}`
          : 'Size unavailable',
      price: cheapestPrice?.price ?? null,
      store: cheapestPrice?.retailer ?? 'No retailer price',
      category: product.category ?? 'Other',
      fresh: freshPrices.length > 0,
      emoji: categoryEmoji[product.category ?? ''] ?? '🛒',
      prices,
      savings,
      dealStore: freshPrices.length > 0
        ? cheapestPrice?.retailer ?? null
        : null,
    };
  });

        setProducts(mappedProducts);
      } catch (err) {
        setError(
          err instanceof Error
            ? err.message
            : 'Unable to load products.'
        );
      } finally {
        setLoading(false);
      }
    }

    loadProducts();
  }, []);

  const filteredProducts = useMemo(() => {
    return products.filter((product) => {
      const matchesSearch =
        `${product.name} ${product.brand}`
          .toLowerCase()
          .includes(search.toLowerCase());

      const matchesCategory =
        category === 'All' || product.category === category;

      const matchesStore =
  store === 'All stores' ||
  product.prices.some((item) => item.retailer === store);

      return matchesSearch && matchesCategory && matchesStore;
    });
 }, [products, search, category, store]);

 const sortedProducts = useMemo(() => {
  const sorted = [...filteredProducts];

  if (sortBy === 'price') {
    return sorted.sort(
      (a, b) => (a.price ?? Infinity) - (b.price ?? Infinity)
    );
  }

  if (sortBy === 'savings') {
    return sorted.sort(
      (a, b) => (b.savings ?? 0) - (a.savings ?? 0)
    );
  }

  return sorted.sort((a, b) =>
    a.name.localeCompare(b.name)
  );
}, [filteredProducts, sortBy]);

 const productsWithSavings = filteredProducts.filter(
  (product) =>
    product.fresh &&
    product.savings !== null &&
    product.savings > 0
);

const totalPotentialSavings = productsWithSavings.reduce(
  (total, product) => total + (product.savings ?? 0),
  0
);

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.content}
      >
        <View style={styles.header}>
          <View>
            <Text style={styles.eyebrow}>DISCOVER</Text>
            <Text style={styles.title}>Explore groceries</Text>
            <Text style={styles.subtitle}>
              Find products and compare prices.
            </Text>
          </View>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>S</Text>
          </View>
        </View>

        <BlurView intensity={75} tint="light" style={styles.searchBox}>
          <Text style={styles.searchIcon}>⌕</Text>
          <TextInput
            value={search}
            onChangeText={setSearch}
            placeholder="Search milk, bread, eggs..."
            placeholderTextColor="#94A3B8"
            style={styles.searchInput}
            returnKeyType="search"
          />
          {search.length > 0 && (
            <Pressable onPress={() => setSearch('')}>
              <Text style={styles.clearButton}>✕</Text>
            </Pressable>
          )}
        </BlurView>

        <Text style={styles.sectionTitle}>Categories</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chipRow}
        >
          {categories.map((item) => {
            const selected = category === item;

            return (
              <Pressable
                key={item}
                onPress={() => setCategory(item)}
                style={[
                  styles.categoryChip,
                  selected && styles.selectedCategory,
                ]}
              >
                <Text
                  style={[
                    styles.categoryText,
                    selected && styles.selectedCategoryText,
                  ]}
                >
                  {item}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        <Text style={styles.sectionTitle}>Choose a store</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chipRow}
        >
          {stores.map((item) => {
            const selected = store === item;

            return (
              <Pressable
                key={item}
                onPress={() => setStore(item)}
                style={[
                  styles.storeChip,
                  selected && styles.selectedStore,
                ]}
              >
                <Text
                  style={[
                    styles.storeText,
                    selected && styles.selectedStoreText,
                  ]}
                >
                  {item}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {!loading && !error && (
          <View style={styles.savingsSummary}>
            <View style={styles.savingsSummaryTop}>
              <View>
                <Text style={styles.savingsSummaryLabel}>
                  POTENTIAL SAVINGS
                </Text>
                <Text style={styles.savingsSummaryAmount}>
                  R{totalPotentialSavings.toFixed(2)}
                </Text>
              </View>

              <View style={styles.savingsSummaryIcon}>
                <Text style={styles.savingsSummaryEmoji}>💰</Text>
              </View>
            </View>

            <Text style={styles.savingsSummaryDescription}>
              {productsWithSavings.length > 0
                ? `Across ${productsWithSavings.length} products with fresh prices from multiple stores.`
                : 'No current savings comparisons available for these products.'}
            </Text>
          </View>
        )}

        <View style={styles.resultsHeader}>
          <View>
            <Text style={styles.sectionTitle}>Products</Text>
            <Text style={styles.resultsCount}>
              {filteredProducts.length} products found
            </Text>
          </View>
          <View style={styles.sortOptions}>
  {[
    { label: 'Price ↑', value: 'price' },
    { label: 'Savings ↓', value: 'savings' },
    { label: 'Name A–Z', value: 'name' },
  ].map((option) => (
    <Pressable
      key={option.value}
      onPress={() => setSortBy(option.value as 'price' | 'savings' | 'name')}
      style={[
        styles.sortOption,
        sortBy === option.value && styles.selectedSortOption,
      ]}
    >
      <Text
        style={[
          styles.sortOptionText,
          sortBy === option.value && styles.selectedSortOptionText,
        ]}
      >
        {option.label}
      </Text>
    </Pressable>
  ))}
</View>
        </View>

        {loading && (
          <View style={styles.emptyState}>
            <ActivityIndicator size="large" color="#22C55E" />
            <Text style={styles.emptyText}>Loading grocery products...</Text>
          </View>
        )}

        {!loading && error !== '' && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>⚠️</Text>
            <Text style={styles.emptyTitle}>Couldn't load products</Text>
            <Text style={styles.emptyText}>{error}</Text>
          </View>
        )}

        {!loading && !error && sortedProducts.map((product) => (
          <View key={product.id} style={styles.productCard}>
            <View style={styles.productImage}>
              <Text style={styles.productEmoji}>{product.emoji}</Text>
            </View>

            <View style={styles.productInfo}>
              <Text style={styles.productBrand}>{product.brand ?? 'Unbranded'}</Text>
              <Text style={styles.productName}>{product.name}</Text>
              <Text style={styles.productDetail}>{product.detail}</Text>
              {product.dealStore && (
  <View style={styles.dealBadge}>
    <Text style={styles.dealBadgeText}>
      BEST PRICE · {product.dealStore}
    </Text>
  </View>
)}

{product.savings !== null && product.savings > 0 && (
  <Text style={styles.savingsText}>
    Save up to R{product.savings.toFixed(2)}
  </Text>
)}
            </View>

            <View style={styles.priceColumn}>
              <Text style={styles.productPrice}>
                {product.price !== null
                  ? `R${product.price.toFixed(2)}`
                  : 'No price'}
              </Text>
              <Text style={styles.priceCaption}>
                {product.price === null
                  ? 'Unavailable'
                  : product.fresh
                    ? 'Fresh price'
                    : 'Price may be outdated'}
              </Text>

              <Pressable
                style={styles.compareButton}
                onPress={() =>
                  router.push({
  pathname: '/product/[productId]',
  params: { productId: String(product.id) },
})
                }
              >
                <Text style={styles.compareButtonText}>Compare</Text>
              </Pressable>
            </View>
          </View>
        ))}

        {!loading && !error && filteredProducts.length === 0 && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>🔎</Text>
            <Text style={styles.emptyTitle}>No products found</Text>
            <Text style={styles.emptyText}>
              Try another search or change your filters.
            </Text>
          </View>
        )}

        <Text style={styles.disclaimer}>
          Prices are sourced from GroceryScout's backend. Check price freshness before shopping.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  content: {
    paddingHorizontal: 22,
    paddingTop: 16,
    paddingBottom: 110,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 26,
  },
  eyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    color: '#22C55E',
    marginBottom: 7,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
    color: '#1E293B',
    letterSpacing: -0.8,
  },
  subtitle: {
    fontSize: 14,
    color: '#64748B',
    marginTop: 6,
  },
  avatar: {
    width: 43,
    height: 43,
    borderRadius: 22,
    backgroundColor: '#DCFCE7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#15803D',
    fontWeight: '800',
    fontSize: 17,
  },
  searchBox: {
    height: 58,
    borderRadius: 19,
    overflow: 'hidden',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 17,
    backgroundColor: 'rgba(255,255,255,0.78)',
    borderWidth: 1,
    borderColor: '#FFFFFF',
    marginBottom: 27,
  },
  searchIcon: {
    fontSize: 29,
    color: '#64748B',
    marginRight: 11,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    color: '#1E293B',
  },
  clearButton: {
    color: '#64748B',
    fontSize: 17,
    padding: 5,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#1E293B',
    marginBottom: 13,
  },
  chipRow: {
    gap: 9,
    paddingBottom: 25,
  },
  categoryChip: {
    paddingHorizontal: 19,
    paddingVertical: 11,
    borderRadius: 22,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  selectedCategory: {
    backgroundColor: '#22C55E',
    borderColor: '#22C55E',
  },
  categoryText: {
    color: '#64748B',
    fontSize: 13,
    fontWeight: '600',
  },
  selectedCategoryText: {
    color: '#FFFFFF',
  },
  storeChip: {
    paddingHorizontal: 15,
    paddingVertical: 10,
    borderRadius: 16,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  selectedStore: {
    backgroundColor: '#DCFCE7',
    borderColor: '#86EFAC',
  },
  storeText: {
    color: '#64748B',
    fontSize: 12,
    fontWeight: '600',
  },
  selectedStoreText: {
    color: '#15803D',
  },
  savingsSummary: {
    backgroundColor: '#14532D',
    borderRadius: 20,
    padding: 18,
    marginBottom: 24,
  },
  savingsSummaryTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  savingsSummaryLabel: {
    color: '#BBF7D0',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  savingsSummaryAmount: {
    color: '#FFFFFF',
    fontSize: 30,
    fontWeight: '800',
    marginTop: 5,
  },
  savingsSummaryIcon: {
    width: 48,
    height: 48,
    borderRadius: 15,
    backgroundColor: 'rgba(255,255,255,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  savingsSummaryEmoji: {
    fontSize: 25,
  },
  savingsSummaryDescription: {
    color: '#DCFCE7',
    fontSize: 11,
    marginTop: 12,
    lineHeight: 17,
  },
  resultsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 3,
    marginBottom: 15,
  },
  resultsCount: {
    color: '#94A3B8',
    fontSize: 12,
    marginTop: -7,
  },
  sortOptions: {
  flexDirection: 'row',
  gap: 5,
  flexWrap: 'wrap',
  justifyContent: 'flex-end',
},
sortOption: {
  paddingHorizontal: 8,
  paddingVertical: 7,
  borderRadius: 10,
  backgroundColor: '#FFFFFF',
  borderWidth: 1,
  borderColor: '#E2E8F0',
},
selectedSortOption: {
  backgroundColor: '#DCFCE7',
  borderColor: '#86EFAC',
},
sortOptionText: {
  color: '#64748B',
  fontSize: 9,
  fontWeight: '700',
},
selectedSortOptionText: {
  color: '#15803D',
},
  productCard: {
    backgroundColor: 'rgba(255,255,255,0.92)',
    borderRadius: 22,
    padding: 13,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#FFFFFF',
    shadowColor: '#64748B',
    shadowOpacity: 0.07,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 5 },
    elevation: 2,
  },
  productImage: {
    width: 68,
    height: 76,
    borderRadius: 17,
    backgroundColor: '#F1F5F9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  productEmoji: {
    fontSize: 34,
  },
  productInfo: {
    flex: 1,
    marginLeft: 13,
  },
  productBrand: {
    color: '#22C55E',
    fontSize: 11,
    fontWeight: '800',
    marginBottom: 3,
  },
  productName: {
    color: '#1E293B',
    fontSize: 14,
    fontWeight: '700',
  },
  productDetail: {
    color: '#94A3B8',
    fontSize: 11,
    marginTop: 4,
  },
  productStore: {
    color: '#64748B',
    fontSize: 11,
    marginTop: 5,
  },
  dealBadge: {
    alignSelf: 'flex-start',
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 7,
    paddingVertical: 4,
    borderRadius: 7,
    marginTop: 6,
  },
  dealBadgeText: {
    color: '#15803D',
    fontSize: 8,
    fontWeight: '800',
  },
  savingsText: {
    color: '#16A34A',
    fontSize: 10,
    fontWeight: '800',
    marginTop: 5,
  },
  priceColumn: {
    alignItems: 'flex-end',
  },
  productPrice: {
    color: '#1E293B',
    fontSize: 16,
    fontWeight: '800',
  },
  priceCaption: {
    color: '#94A3B8',
    fontSize: 9,
    marginTop: 3,
  },
  compareButton: {
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 11,
    paddingVertical: 7,
    borderRadius: 12,
    marginTop: 8,
  },
  compareButtonText: {
    color: '#15803D',
    fontSize: 10,
    fontWeight: '800',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 45,
  },
  emptyEmoji: {
    fontSize: 38,
    marginBottom: 12,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: '#1E293B',
  },
  emptyText: {
    color: '#94A3B8',
    fontSize: 13,
    marginTop: 7,
    textAlign: 'center',
  },
  disclaimer: {
    color: '#94A3B8',
    fontSize: 10,
    textAlign: 'center',
    marginTop: 17,
  },
});
