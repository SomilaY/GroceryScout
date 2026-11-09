
import { useEffect, useState } from 'react';
import { Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { getUser, removeToken, type AuthUser } from '@/services/auth';
import {
  ScrollView,
  StyleSheet,
    ActivityIndicator,
  Text,
  TextInput,
  View,
  Pressable,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { fetchProducts, type Product } from '@/services/products';

const stores = ['All stores', 'Checkers', 'Shoprite', 'Pick n Pay', 'Woolworths'];

export default function HomeScreen() {
  const [search, setSearch] = useState('');
  const [selectedStore, setSelectedStore] = useState('All stores');
    const [products, setProducts] = useState<Product[]>([]);
  const [productsLoading, setProductsLoading] = useState(true);
  const [productsError, setProductsError] = useState('');
  const [user, setUser] = useState<AuthUser | null>(null);

  useEffect(() => {
    async function loadUser() {
      const savedUser = await getUser();
      setUser(savedUser);
    }

    loadUser();
  }, []);

  useEffect(() => {
    const timeout = setTimeout(async () => {
      try {
        setProductsLoading(true);
        setProductsError('');

        const response = await fetchProducts(search.trim());

        setProducts(response.products);
      } catch (error) {
        setProductsError(
          error instanceof Error
            ? error.message
            : 'Unable to load products.'
        );
      } finally {
        setProductsLoading(false);
      }
    }, 300);

    return () => clearTimeout(timeout);
  }, [search]);

  const router = useRouter();

  function handleLogout() {
    Alert.alert(
      'Log out',
      'Are you sure you want to log out of GroceryScout?',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Log out',
          style: 'destructive',
          onPress: async () => {
            await removeToken();
            router.replace('/login');
          },
        },
      ]
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.container}
      >
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={styles.brand}>
              Grocery<Text style={styles.brandAccent}>Scout</Text>
            </Text>
            <Text style={styles.tagline}>SHOP SMARTER. SAVE MORE.</Text>
          </View>

         <Pressable style={styles.avatar}>
  <Text style={styles.avatarText}>
    {user?.name
      ? user.name
          .trim()
          .split(/\s+/)
          .slice(0, 2)
          .map((part) => part.charAt(0))
          .join('')
          .toUpperCase()
      : 'GS'}
  </Text>
</Pressable>
        </View>

        {/* Welcome */}
        <View style={styles.hero}>
          <Text style={styles.eyebrow}>YOUR SMARTER GROCERY COMPANION</Text>
          <Text style={styles.title}>
            Every rand{'\n'}<Text style={styles.titleAccent}>counts.</Text>
          </Text>
          <Text style={styles.description}>
            Compare grocery prices across South Africa's leading supermarkets.
          </Text>
        </View>

        {/* Glass Search */}
        <View style={styles.searchWrapper}>
          <BlurView
            intensity={Platform.OS === 'ios' ? 65 : 40}
            tint="light"
            style={styles.searchGlass}
          >
            <Text style={styles.searchIcon}>⌕</Text>
            <TextInput
              value={search}
              onChangeText={setSearch}
              placeholder="Search groceries, brands..."
              placeholderTextColor="#94A3B8"
              style={styles.searchInput}
            />
            <Text style={styles.searchFilter}>☷</Text>
          </BlurView>
        </View>

        {/* Store filters */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Supermarkets</Text>
          <Text style={styles.muted}>Compare prices</Text>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.storeList}
        >
          {stores.map((store) => {
            const active = selectedStore === store;

            return (
              <Pressable
                key={store}
                onPress={() => setSelectedStore(store)}
                style={[styles.storeChip, active && styles.storeChipActive]}
              >
                <Text
                  style={[
                    styles.storeText,
                    active && styles.storeTextActive,
                  ]}
                >
                  {store}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Savings banner */}
        <LinearGradient
          colors={['#166534', '#22C55E']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.savingsCard}
        >
          <View style={styles.savingsTop}>
            <Text style={styles.savingsLabel}>GROCERYSCOUT INSIGHTS</Text>
            <Text style={styles.sparkle}>✦</Text>
          </View>

          <Text style={styles.savingsTitle}>
            Your basket.{'\n'}Your best price.
          </Text>

          <Text style={styles.savingsDescription}>
            Find out where your shopping list costs less.
          </Text>

          <View style={styles.savingsBottom}>
            <Text style={styles.savingsLink}>Compare your basket</Text>
            <Text style={styles.arrow}>↗</Text>
          </View>

          <View style={styles.glow} />
        </LinearGradient>

        {/* Products */}
        <View style={styles.productHeader}>
          <View>
            <Text style={styles.sectionTitle}>Popular products</Text>
            <Text style={styles.muted}>Find the best available prices</Text>
          </View>
          <Pressable onPress={() => router.push('/explore')}>
            <Text style={styles.seeAll}>View all ↗</Text>
          </Pressable>
        </View>

        {productsLoading ? (
          <ActivityIndicator size="large" color="#16A34A" />
        ) : productsError ? (
          <Text style={styles.disclaimer}>{productsError}</Text>
        ) : products.length === 0 ? (
          <Text style={styles.disclaimer}>
            No products available yet.
          </Text>
        ) : (
          products
            .filter((product) => {
              if (selectedStore === 'All stores') return true;

              return product.prices.some(
                (price) => price.retailer === selectedStore
              );
            })
            .slice(0, 4)
            .map((product) => {
              const matchingPrices =
                selectedStore === 'All stores'
                  ? product.prices
                  : product.prices.filter(
                      (price) => price.retailer === selectedStore
                    );

              const freshPrices = matchingPrices.filter(
                (price) => price.fresh
              );

              const availablePrices =
                freshPrices.length > 0 ? freshPrices : matchingPrices;

              const cheapestPrice = [...availablePrices].sort(
                (a, b) => a.price - b.price
              )[0];

              return (
                <View key={product.id} style={styles.productCard}>
                  <View style={styles.productImage}>
                    <Text style={styles.productEmoji}>🛒</Text>
                  </View>

                  <View style={styles.productDetails}>
                    <Text style={styles.productBrand}>
                      {product.brand ?? 'Unbranded'}
                    </Text>

                    <Text style={styles.productName}>
                      {product.name}
                    </Text>

                    <Text style={styles.productSize}>
                      {product.quantity && product.unit
                        ? `${product.quantity} ${product.unit}`
                        : 'Size unavailable'}
                    </Text>

                    <View style={styles.bestPrice}>
                      <Text style={styles.bestPriceText}>
                        {cheapestPrice
                          ? cheapestPrice.fresh
                            ? 'Fresh price'
                            : 'Price may be outdated'
                          : 'Unavailable'}
                      </Text>
                    </View>
                  </View>

                  <View style={styles.priceColumn}>
                    <Text style={styles.price}>
                      {cheapestPrice
                        ? `R${cheapestPrice.price.toFixed(2)}`
                        : 'No price'}
                    </Text>

                    <Text style={styles.storeName}>
                      {cheapestPrice?.retailer ?? 'No retailer price'}
                    </Text>

                    <Pressable
                      onPress={() =>
                        router.push({
                          pathname: '/product/[productId]',
                          params: { productId: String(product.id) },
                        })
                      }
                    >
                      <Text style={styles.compare}>Compare →</Text>
                    </Pressable>
                  </View>
                </View>
              );
            })
        )}

     <Text style={styles.disclaimer}>
  Prices are sourced from GroceryScout's database. Price freshness may vary.
</Text>

        <View style={styles.accountCard}>
          <View style={styles.accountDetails}>
            <Text style={styles.accountTitle}>
              {user?.name || 'Your account'}
            </Text>
            <Text style={styles.accountSubtitle}>
              {user?.email || 'Manage your GroceryScout session'}
            </Text>
          </View>

          <Pressable
            style={styles.logoutButton}
            onPress={handleLogout}
          >
            <Text style={styles.logoutButtonText}>Log out</Text>
          </Pressable>
        </View>

        <View style={styles.bottomSpace} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  container: {
    paddingHorizontal: 22,
    paddingTop: 12,
    paddingBottom: 30,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  brand: {
    fontSize: 25,
    fontWeight: '800',
    color: '#1E293B',
    letterSpacing: -1,
  },
  brandAccent: {
    color: '#22C55E',
  },
  tagline: {
    fontSize: 9,
    letterSpacing: 1.5,
    color: '#94A3B8',
    marginTop: 4,
    fontWeight: '700',
  },
  avatar: {
    height: 42,
    width: 42,
    borderRadius: 21,
    backgroundColor: '#DCFCE7',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#FFFFFF',
  },
  avatarText: {
    color: '#15803D',
    fontWeight: '800',
    fontSize: 16,
  },
  hero: {
    marginTop: 38,
    marginBottom: 25,
  },
  eyebrow: {
    fontSize: 9,
    fontWeight: '800',
    letterSpacing: 1.6,
    color: '#22C55E',
    marginBottom: 12,
  },
  title: {
    fontSize: 43,
    lineHeight: 47,
    fontWeight: '800',
    letterSpacing: -2,
    color: '#1E293B',
  },
  titleAccent: {
    color: '#22C55E',
  },
  description: {
    color: '#64748B',
    fontSize: 13,
    lineHeight: 21,
    marginTop: 12,
    maxWidth: 300,
  },
  searchWrapper: {
    borderRadius: 18,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.9)',
    marginBottom: 30,
    backgroundColor: 'rgba(255,255,255,0.8)',
    elevation: 3,
    shadowColor: '#64748B',
    shadowOpacity: 0.08,
    shadowRadius: 15,
    shadowOffset: { width: 0, height: 5 },
  },
  searchGlass: {
    height: 58,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 17,
  },
  searchIcon: {
    fontSize: 27,
    color: '#64748B',
    marginRight: 12,
  },
  searchInput: {
    flex: 1,
    fontSize: 13,
    color: '#1E293B',
  },
  searchFilter: {
    fontSize: 21,
    color: '#22C55E',
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: '#1E293B',
    letterSpacing: -0.4,
  },
  muted: {
    fontSize: 11,
    color: '#94A3B8',
    marginTop: 5,
  },
  storeList: {
    gap: 9,
    paddingVertical: 16,
  },
  storeChip: {
    backgroundColor: 'rgba(255,255,255,0.8)',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    paddingHorizontal: 15,
    paddingVertical: 10,
    borderRadius: 22,
  },
  storeChipActive: {
    backgroundColor: '#DCFCE7',
    borderColor: '#86EFAC',
  },
  storeText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#64748B',
  },
  storeTextActive: {
    color: '#15803D',
  },
  savingsCard: {
    borderRadius: 23,
    padding: 22,
    overflow: 'hidden',
    marginTop: 5,
    marginBottom: 31,
  },
  savingsTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  savingsLabel: {
    fontSize: 9,
    color: '#D1FAE5',
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  sparkle: {
    fontSize: 20,
    color: '#BBF7D0',
  },
  savingsTitle: {
    fontSize: 27,
    lineHeight: 32,
    fontWeight: '800',
    color: '#FFFFFF',
    marginTop: 20,
    letterSpacing: -0.8,
  },
  savingsDescription: {
    color: '#DCFCE7',
    fontSize: 12,
    marginTop: 9,
  },
  savingsBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 23,
    gap: 10,
  },
  savingsLink: {
    fontSize: 12,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  arrow: {
    color: '#FFFFFF',
    fontSize: 17,
  },
  glow: {
    position: 'absolute',
    width: 170,
    height: 170,
    borderRadius: 85,
    backgroundColor: 'rgba(255,255,255,0.08)',
    right: -65,
    top: 25,
  },
  productHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 17,
  },
  seeAll: {
    fontSize: 11,
    fontWeight: '700',
    color: '#22C55E',
  },
  productCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.85)',
    borderRadius: 19,
    padding: 13,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#FFFFFF',
    elevation: 2,
    shadowColor: '#64748B',
    shadowOpacity: 0.05,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
  },
  productImage: {
    width: 66,
    height: 75,
    borderRadius: 15,
    backgroundColor: '#F0FDF4',
    justifyContent: 'center',
    alignItems: 'center',
  },
  productEmoji: {
    fontSize: 32,
  },
  productDetails: {
    flex: 1,
    marginLeft: 13,
  },
  productBrand: {
    fontSize: 10,
    color: '#94A3B8',
    fontWeight: '700',
  },
  productName: {
    fontSize: 12,
    color: '#1E293B',
    fontWeight: '800',
    marginTop: 3,
  },
  productSize: {
    fontSize: 10,
    color: '#94A3B8',
    marginTop: 3,
  },
  bestPrice: {
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    alignSelf: 'flex-start',
    marginTop: 7,
  },
  bestPriceText: {
    color: '#15803D',
    fontSize: 9,
    fontWeight: '700',
  },
  priceColumn: {
    alignItems: 'flex-end',
  },
  price: {
    fontSize: 15,
    fontWeight: '800',
    color: '#15803D',
  },
  storeName: {
    fontSize: 9,
    color: '#64748B',
    marginTop: 5,
  },
  compare: {
    fontSize: 9,
    fontWeight: '700',
    color: '#22C55E',
    marginTop: 9,
  },
  productMessage: {
    color: '#64748B',
    fontSize: 13,
    textAlign: 'center',
    paddingVertical: 24,
  },
  disclaimer: {
    fontSize: 9,
    color: '#94A3B8',
    textAlign: 'center',
    marginTop: 12,
  },
  accountCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 18,
    padding: 18,
    marginTop: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  accountDetails: {
    flex: 1,
    marginRight: 12,
  },
  accountTitle: {
    color: '#1E293B',
    fontSize: 14,
    fontWeight: '800',
  },
  accountSubtitle: {
    color: '#94A3B8',
    fontSize: 10,
    marginTop: 5,
  },
  logoutButton: {
    backgroundColor: '#FEF2F2',
    paddingHorizontal: 15,
    paddingVertical: 10,
    borderRadius: 10,
  },
  logoutButtonText: {
    color: '#DC2626',
    fontSize: 11,
    fontWeight: '800',
  },
  bottomSpace: {
    height: 20,
  },
});
