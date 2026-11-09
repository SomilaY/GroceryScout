
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
   ActivityIndicator,
  Image,
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { fetchProduct, Product } from '@/services/products';

import {
  addBasketItem,
  getOrCreateBasket,
} from '@/services/baskets';

export default function ProductDetailsScreen() {
  const { productId } = useLocalSearchParams<{
    productId: string;
  }>();

  const router = useRouter();

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
    const [adding, setAdding] = useState(false);
  const [addMessage, setAddMessage] = useState('');

  useEffect(() => {
    async function loadProduct() {
      try {
        setLoading(true);
        setError('');

        const result = await fetchProduct(Number(productId));
        setProduct(result);
      } catch {
        setError('Unable to load this product. Please try again.');
      } finally {
        setLoading(false);
      }
    }

    if (productId) {
      loadProduct();
    }
  }, [productId]);

    async function handleAddToList() {
    if (!product || adding) return;

    setAdding(true);
    setAddMessage('');

    try {
      const basket = await getOrCreateBasket();

         const response = await addBasketItem(
        basket.id,
        product.id,
        1
      );

      const quantity = response.item.quantity;

      setAddMessage(
        `✓ Added to My List. You now have ${quantity} ${quantity === 1 ? 'unit' : 'units'}.`
      );
    } catch (err) {
      setAddMessage(
        err instanceof Error
          ? err.message
          : 'Could not add this product.'
      );
    } finally {
      setAdding(false);
    }
  }

  const prices = product?.prices ?? [];
    const productImage =
    prices.find((item) => item.image_url)?.image_url ?? null;
  const freshPrices = prices.filter((item) => item.fresh);

  const cheapest = freshPrices.length
    ? Math.min(...freshPrices.map((item) => item.price))
    : null;

  if (loading) {
    return (
      <SafeAreaView style={styles.center}>
        <ActivityIndicator size="large" color="#16A34A" />
        <Text style={styles.loadingText}>Loading product...</Text>
      </SafeAreaView>
    );
  }

  if (error || !product) {
    return (
      <SafeAreaView style={styles.center}>
        <Text style={styles.errorText}>
          {error || 'Product not found.'}
        </Text>

        <Pressable
          style={styles.primaryButton}
          onPress={() => router.back()}
        >
          <Text style={styles.primaryButtonText}>Go back</Text>
        </Pressable>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Pressable onPress={() => router.back()}>
          <Text style={styles.backText}>‹ Back to Explore</Text>
        </Pressable>

        <View style={styles.productCard}>
         {productImage ? (
  <Image
    source={{ uri: productImage }}
    style={styles.productImage}
    resizeMode="contain"
  />
) : (
  <View style={styles.productIcon}>
    <Text style={styles.productEmoji}>🛒</Text>
  </View>
)}

          <Text style={styles.category}>
            {product.category || 'Grocery product'}
          </Text>

          <Text style={styles.productName}>{product.name}</Text>

          {product.brand ? (
            <Text style={styles.brand}>{product.brand}</Text>
          ) : null}

          {product.quantity ? (
            <Text style={styles.quantity}>
              {product.quantity} {product.unit || ''}
            </Text>
          ) : null}
        </View>

        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Available prices</Text>
          <Text style={styles.sectionSubtitle}>
            {prices.length} retailer{prices.length === 1 ? '' : 's'}
          </Text>
        </View>

        {prices.length === 0 ? (
          <View style={styles.emptyCard}>
            <Text style={styles.emptyText}>
              No retailer prices are available yet.
            </Text>
          </View>
        ) : (
          prices.map((store, index) => {
            const isCheapest =
              store.fresh && store.price === cheapest;

            return (
              <View key={`${store.retailer}-${index}`} style={styles.priceCard}>
                <View style={styles.storeInfo}>
                  <Text style={styles.storeName}>{store.retailer}</Text>

                  <Text
                    style={[
                      styles.freshness,
                      store.fresh
                        ? styles.freshText
                        : styles.staleText,
                    ]}
                  >
                    {store.fresh ? 'Current price' : 'Price may be outdated'}
                  </Text>
                </View>

                               <View style={styles.priceInfo}>
                  <Text style={styles.price}>
                    R{store.price.toFixed(2)}
                  </Text>

                  {isCheapest ? (
                    <Text style={styles.bestPrice}>BEST PRICE</Text>
                  ) : null}

                  {store.product_url ? (
                    <Pressable
                      style={styles.retailerLink}
                      onPress={() =>
                        Linking.openURL(store.product_url as string)
                      }
                    >
                      <Text style={styles.retailerLinkText}>
                        View at retailer ↗
                      </Text>
                    </Pressable>
                  ) : null}
                </View>
              </View>
            );
          })
        )}

        <View style={styles.noteCard}>
          <Text style={styles.noteTitle}>About these prices</Text>
          <Text style={styles.noteText}>
            Prices are based on the latest information available in
            GroceryScout. Always confirm the price with the retailer
            before purchasing.
          </Text>
        </View>

                <Pressable
          style={[
            styles.addToListButton,
            adding && styles.disabledButton,
          ]}
          onPress={handleAddToList}
          disabled={adding}
        >
          <Text style={styles.addToListText}>
            {adding ? 'Adding...' : '+ Add to My List'}
          </Text>
        </Pressable>

        {addMessage !== '' && (
          <Text style={styles.addMessage}>
            {addMessage}
          </Text>
        )}

        <Pressable
          style={styles.primaryButton}
          onPress={() =>
            router.push({
              pathname: '/compare',
              params: { productId: String(product.id) },
            })
          }
        >
          <Text style={styles.primaryButtonText}>
            View price history and comparison
          </Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  content: {
    padding: 20,
    paddingBottom: 40,
  },
  center: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  loadingText: {
    marginTop: 12,
    color: '#64748B',
    fontSize: 14,
  },
  errorText: {
    color: '#DC2626',
    fontSize: 15,
    textAlign: 'center',
    marginBottom: 20,
  },
  backText: {
    color: '#16A34A',
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 20,
  },
  productCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    marginBottom: 28,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  productImage: {
  width: 180,
  height: 180,
  marginBottom: 16,
},
  productIcon: {
    width: 76,
    height: 76,
    borderRadius: 22,
    backgroundColor: '#DCFCE7',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  productEmoji: {
    fontSize: 36,
  },
  category: {
    color: '#16A34A',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 8,
  },
  productName: {
    color: '#0F172A',
    fontSize: 25,
    fontWeight: '800',
    textAlign: 'center',
  },
  brand: {
    color: '#64748B',
    fontSize: 16,
    marginTop: 6,
  },
  quantity: {
    color: '#64748B',
    fontSize: 14,
    marginTop: 8,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  sectionTitle: {
    color: '#0F172A',
    fontSize: 19,
    fontWeight: '800',
  },
  sectionSubtitle: {
    color: '#64748B',
    fontSize: 13,
  },
  priceCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 18,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  storeInfo: {
    flex: 1,
    paddingRight: 10,
  },
  storeName: {
    color: '#0F172A',
    fontSize: 16,
    fontWeight: '700',
  },
  freshness: {
    fontSize: 12,
    marginTop: 5,
  },
  freshText: {
    color: '#16A34A',
  },
  staleText: {
    color: '#D97706',
  },
  priceInfo: {
    alignItems: 'flex-end',
  },
  price: {
    color: '#0F172A',
    fontSize: 19,
    fontWeight: '800',
  },
  bestPrice: {
    color: '#16A34A',
    fontSize: 10,
    fontWeight: '800',
    marginTop: 5,
  },
  emptyCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  emptyText: {
    color: '#64748B',
    fontSize: 14,
  },
  noteCard: {
    backgroundColor: '#EFF6FF',
    borderRadius: 16,
    padding: 18,
    marginTop: 12,
    marginBottom: 24,
  },
  noteTitle: {
    color: '#1E40AF',
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 6,
  },
  noteText: {
    color: '#1E40AF',
    fontSize: 13,
    lineHeight: 20,
  },
  primaryButton: {
    backgroundColor: '#16A34A',
    padding: 17,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
    textAlign: 'center',
  },
    addToListButton: {
    backgroundColor: '#DCFCE7',
    padding: 17,
    borderRadius: 14,
    alignItems: 'center',
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#86EFAC',
  },
  addToListText: {
    color: '#15803D',
    fontSize: 15,
    fontWeight: '800',
  },
  disabledButton: {
    opacity: 0.5,
  },
  addMessage: {
    color: '#15803D',
    fontSize: 13,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 15,
  },
    retailerLink: {
    marginTop: 8,
    paddingVertical: 5,
  },
  retailerLinkText: {
    color: '#2563EB',
    fontSize: 12,
    fontWeight: '700',
  },
});
