import { useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  Pressable,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';

const products = [
  {
    id: '1',
    name: 'Full Cream Milk',
    brand: 'Clover',
    detail: '2 litre',
    price: 'R29.99',
    store: 'Checkers',
    emoji: '🥛',
    category: 'Dairy',
  },
  {
    id: '2',
    name: 'White Bread',
    brand: 'Albany',
    detail: '700g',
    price: 'R18.99',
    store: 'Shoprite',
    emoji: '🍞',
    category: 'Bakery',
  },
  {
    id: '3',
    name: 'Large Eggs',
    brand: 'Nulaid',
    detail: '18 pack',
    price: 'R54.99',
    store: 'Pick n Pay',
    emoji: '🥚',
    category: 'Dairy',
  },
  {
    id: '4',
    name: 'Sunflower Oil',
    brand: 'Sunfoil',
    detail: '2 litre',
    price: 'R49.99',
    store: 'Woolworths',
    emoji: '🫒',
    category: 'Pantry',
  },
  {
    id: '5',
    name: 'Brown Rice',
    brand: 'Tastic',
    detail: '2kg',
    price: 'R42.99',
    store: 'Checkers',
    emoji: '🍚',
    category: 'Pantry',
  },
];

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

  const filteredProducts = useMemo(() => {
    return products.filter((product) => {
      const matchesSearch =
        `${product.name} ${product.brand}`
          .toLowerCase()
          .includes(search.toLowerCase());

      const matchesCategory =
        category === 'All' || product.category === category;

      const matchesStore =
        store === 'All stores' || product.store === store;

      return matchesSearch && matchesCategory && matchesStore;
    });
  }, [products, search, category, store]);

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
        

        <View style={styles.resultsHeader}>
          <View>
            <Text style={styles.sectionTitle}>Products</Text>
            <Text style={styles.resultsCount}>
              {filteredProducts.length} products found
            </Text>
          </View>
          <Text style={styles.sortLabel}>Popular ↓</Text>
        </View>

        {filteredProducts.map((product) => (
          <View key={product.id} style={styles.productCard}>
            <View style={styles.productImage}>
              <Text style={styles.productEmoji}>{product.emoji}</Text>
            </View>

            <View style={styles.productInfo}>
              <Text style={styles.productBrand}>{product.brand}</Text>
              <Text style={styles.productName}>{product.name}</Text>
              <Text style={styles.productDetail}>{product.detail}</Text>
              <Text style={styles.productStore}>{product.store}</Text>
            </View>

            <View style={styles.priceColumn}>
              <Text style={styles.productPrice}>{product.price}</Text>
              <Text style={styles.priceCaption}>Demo price</Text>
              <Pressable
  style={styles.compareButton}
  onPress={() =>
    router.push({
      pathname: '/compare',
      params: { productId: product.id },
    })
  }
>
  <Text style={styles.compareButtonText}>Compare</Text>
</Pressable>
            </View>
          </View>
        ))}

        {filteredProducts.length === 0 && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>🔎</Text>
            <Text style={styles.emptyTitle}>No products found</Text>
            <Text style={styles.emptyText}>
              Try another search or change your filters.
            </Text>
          </View>
        )}

        <Text style={styles.disclaimer}>
          Demonstration products and prices only. Not live retailer prices.
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
  sortLabel: {
    color: '#64748B',
    fontSize: 12,
    fontWeight: '600',
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
