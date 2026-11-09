
import { useCallback, useEffect, useState } from 'react';
import { useFocusEffect, useRouter } from 'expo-router';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';

import {
  addBasketItem,
  getOrCreateBasket,
  removeBasketItem,
  updateBasketItem,
  type Basket,
} from '@/services/baskets';

import {
  fetchProduct,
  fetchProducts,
  type Product,
} from '@/services/products';

type GroceryItem = {
  id: number;
  productId: number;
  name: string;
  quantity: number;
  price: number;
  checked: boolean;
};

export default function ListScreen() {
  const router = useRouter();
  const [basket, setBasket] = useState<Basket | null>(null);
  const [items, setItems] = useState<GroceryItem[]>([]);
  const [searchResults, setSearchResults] = useState<Product[]>([]);
  const [newItem, setNewItem] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const loadBasket = useCallback(async () => {
    setLoading(true);
    setError('');

    try {
      const currentBasket = await getOrCreateBasket();
      setBasket(currentBasket);

      const products = await Promise.all(
        currentBasket.items.map((item) =>
          fetchProduct(item.product_id)
        )
      );

      setItems(
        currentBasket.items.map((item) => {
          const product = products.find(
            (entry) => entry.id === item.product_id
          );

          const prices = product?.prices ?? [];
          const cheapestPrice = prices.length
            ? Math.min(...prices.map((price) => price.price))
            : 0;

          return {
            id: item.id,
            productId: item.product_id,
            name: item.product_name,
            quantity: item.quantity,
            price: cheapestPrice,
            checked: false,
          };
        })
      );
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Could not load your basket.'
      );
    } finally {
      setLoading(false);
    }
  }, []);

 useFocusEffect(
  useCallback(() => {
    loadBasket();
  }, [loadBasket])
);

  useEffect(() => {
    let active = true;

    const timer = setTimeout(async () => {
      if (!newItem.trim()) {
        setSearchResults([]);
        return;
      }

      try {
        const response = await fetchProducts(newItem.trim());

        if (active) {
          setSearchResults(response.products);
        }
      } catch {
        if (active) {
          setSearchResults([]);
        }
      }
    }, 300);

    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [newItem]);

  async function addItem(product: Product) {
    if (!basket || busy) return;

    setBusy(true);
    setError('');

    try {
      await addBasketItem(basket.id, product.id, 1);
      setNewItem('');
      setSearchResults([]);
      await loadBasket();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Could not add this product.'
      );
    } finally {
      setBusy(false);
    }
  }

  async function changeQuantity(item: GroceryItem, amount: number) {
    if (!basket || busy) return;

    const quantity = item.quantity + amount;

    if (quantity < 1) return;

    setBusy(true);
    setError('');

    try {
      await updateBasketItem(basket.id, item.id, quantity);

      setItems((current) =>
        current.map((entry) =>
          entry.id === item.id
            ? { ...entry, quantity }
            : entry
        )
      );
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Could not update quantity.'
      );
    } finally {
      setBusy(false);
    }
  }

  async function toggleItem(id: number) {
    setItems((current) =>
      current.map((item) =>
        item.id === id
          ? { ...item, checked: !item.checked }
          : item
      )
    );
  }

  async function deleteItem(id: number) {
    if (!basket || busy) return;

    setBusy(true);
    setError('');

    try {
      await removeBasketItem(basket.id, id);
      setItems((current) => current.filter((item) => item.id !== id));
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Could not remove this product.'
      );
    } finally {
      setBusy(false);
    }
  }

  const total = items
    .filter((item) => !item.checked)
    .reduce((sum, item) => sum + item.price * item.quantity, 0);

  const remaining = items.filter((item) => !item.checked).length;
  const completed = items.filter((item) => item.checked).length;

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={styles.content}
      >
        <View style={styles.header}>
          <View>
            <Text style={styles.eyebrow}>YOUR SHOPPING</Text>
            <Text style={styles.title}>My list</Text>
            <Text style={styles.subtitle}>
              Everything you need, in one place.
            </Text>
          </View>

          <View style={styles.avatar}>
            <Text style={styles.avatarText}>S</Text>
          </View>
        </View>

        <LinearGradient
          colors={['#15803D', '#22C55E']}
          style={styles.summaryCard}
        >
          <Text style={styles.summaryLabel}>
            ESTIMATED REMAINING TOTAL
          </Text>
          <Text style={styles.summaryAmount}>
            R{total.toFixed(2)}
          </Text>

          <View style={styles.summaryFooter}>
            <Text style={styles.summaryDetail}>
              {remaining} items remaining
            </Text>
            <Text style={styles.summaryDetail}>
              {completed} completed
            </Text>
          </View>
               </LinearGradient>

        <Pressable
          style={[
            styles.compareButton,
            (items.length === 0 || loading) && styles.compareButtonDisabled,
          ]}
          onPress={() => router.push('/basket-compare')}
          disabled={items.length === 0 || loading}
        >
          <View>
            <Text style={styles.compareButtonText}>
              Compare basket prices
            </Text>
            <Text style={styles.compareButtonCaption}>
              See which retailer gives you the cheapest basket
            </Text>
          </View>
          <Text style={styles.compareButtonArrow}>→</Text>
        </Pressable>

        <Text style={styles.sectionTitle}>Add groceries</Text>

        <View style={styles.addRow}>
          <TextInput
            value={newItem}
            onChangeText={setNewItem}
            placeholder="Search GroceryScout products..."
            placeholderTextColor="#94A3B8"
            style={styles.input}
            returnKeyType="search"
          />
        </View>

        {searchResults.map((product) => {
          const cheapestPrice = product.prices.length
            ? Math.min(...product.prices.map((price) => price.price))
            : null;

          return (
            <View key={product.id} style={styles.searchResult}>
              <View style={styles.itemInfo}>
                <Text style={styles.itemName}>{product.name}</Text>
                <Text style={styles.itemPrice}>
                  {product.brand || 'Grocery product'}
                  {cheapestPrice !== null
                    ? ` · From R${cheapestPrice.toFixed(2)}`
                    : ' · No price available'}
                </Text>
              </View>

              <Pressable
                onPress={() => addItem(product)}
                disabled={busy}
                style={styles.addSmallButton}
              >
                <Text style={styles.addSmallButtonText}>Add +</Text>
              </Pressable>
            </View>
          );
        })}

        {newItem.trim().length > 0 &&
          searchResults.length === 0 && (
            <Text style={styles.searchHint}>
              No matching products found.
            </Text>
          )}

        {error !== '' && (
          <Text style={styles.errorText}>{error}</Text>
        )}

        <View style={styles.listHeader}>
          <Text style={styles.sectionTitle}>Your groceries</Text>
          <Text style={styles.itemCount}>
            {items.length} items
          </Text>
        </View>

        {loading ? (
          <ActivityIndicator
            size="large"
            color="#22C55E"
            style={styles.loader}
          />
        ) : (
          <>
            {items.map((item) => (
              <View
                key={item.id}
                style={[
                  styles.itemCard,
                  item.checked && styles.completedCard,
                ]}
              >
                <Pressable
                  onPress={() => toggleItem(item.id)}
                  style={[
                    styles.checkbox,
                    item.checked && styles.checkedBox,
                  ]}
                >
                  {item.checked && (
                    <Text style={styles.checkmark}>✓</Text>
                  )}
                </Pressable>

                <View style={styles.itemInfo}>
                  <Text
                    style={[
                      styles.itemName,
                      item.checked && styles.completedText,
                    ]}
                  >
                    {item.name}
                  </Text>
                  <Text style={styles.itemPrice}>
                    {item.price > 0
                      ? `From R${item.price.toFixed(2)} each`
                      : 'Price not available'}
                  </Text>
                </View>

                <View style={styles.quantityControls}>
                  <Pressable
                    onPress={() => changeQuantity(item, -1)}
                    style={styles.quantityButton}
                    disabled={busy || item.quantity <= 1}
                  >
                    <Text style={styles.quantityButtonText}>−</Text>
                  </Pressable>

                  <Text style={styles.quantity}>
                    {item.quantity}
                  </Text>

                  <Pressable
                    onPress={() => changeQuantity(item, 1)}
                    style={styles.quantityButton}
                    disabled={busy}
                  >
                    <Text style={styles.quantityButtonText}>+</Text>
                  </Pressable>
                </View>

                <Pressable
                  onPress={() => deleteItem(item.id)}
                  style={styles.removeButton}
                  disabled={busy}
                >
                  <Text style={styles.removeText}>×</Text>
                </Pressable>
              </View>
            ))}

            {items.length === 0 && (
              <View style={styles.emptyState}>
                <Text style={styles.emptyEmoji}>🛒</Text>
                <Text style={styles.emptyTitle}>
                  Your list is empty
                </Text>
                <Text style={styles.emptyText}>
                  Search for a product above to get started.
                </Text>
              </View>
            )}
          </>
        )}

        <Text style={styles.disclaimer}>
          Prices are estimates based on the lowest available retailer
          price. Checked items are marked locally.
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
    marginBottom: 25,
  },
  eyebrow: {
    color: '#22C55E',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 7,
  },
  title: {
    color: '#1E293B',
    fontSize: 29,
    fontWeight: '800',
  },
  subtitle: {
    color: '#64748B',
    fontSize: 13,
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
  summaryCard: {
    borderRadius: 24,
    padding: 22,
    marginBottom: 29,
  },
  summaryLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1.3,
  },
  summaryAmount: {
    color: '#FFFFFF',
    fontSize: 36,
    fontWeight: '900',
    marginTop: 9,
  },
   summaryFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 15,
  },
  summaryDetail: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  sectionTitle: {
    color: '#1E293B',
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 13,
  },
  addRow: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 12,
  },
  input: {
    flex: 1,
    height: 53,
    backgroundColor: '#FFFFFF',
    borderRadius: 17,
    paddingHorizontal: 16,
    fontSize: 14,
    color: '#1E293B',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  searchResult: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 15,
    padding: 13,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  addSmallButton: {
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 13,
    paddingVertical: 9,
    borderRadius: 11,
  },
  addSmallButtonText: {
    color: '#15803D',
    fontSize: 12,
    fontWeight: '800',
  },
  searchHint: {
    color: '#94A3B8',
    fontSize: 12,
    marginBottom: 15,
  },
  errorText: {
    color: '#DC2626',
    fontSize: 12,
    marginBottom: 12,
  },
  listHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 20,
  },
  itemCount: {
    color: '#94A3B8',
    fontSize: 12,
  },
  itemCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 19,
    padding: 12,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  completedCard: {
    backgroundColor: '#F8FAFC',
    opacity: 0.7,
  },
  checkbox: {
    width: 23,
    height: 23,
    borderRadius: 8,
    borderWidth: 1.5,
    borderColor: '#CBD5E1',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkedBox: {
    backgroundColor: '#22C55E',
    borderColor: '#22C55E',
  },
  checkmark: {
    color: '#FFFFFF',
    fontWeight: '900',
  },
  itemInfo: {
    flex: 1,
    marginLeft: 11,
  },
  itemName: {
    color: '#1E293B',
    fontSize: 12,
    fontWeight: '800',
  },
  completedText: {
    textDecorationLine: 'line-through',
    color: '#94A3B8',
  },
  itemPrice: {
    color: '#94A3B8',
    fontSize: 10,
    marginTop: 5,
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
  },
  quantityButton: {
    width: 25,
    height: 25,
    borderRadius: 9,
    backgroundColor: '#F1F5F9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  quantityButtonText: {
    color: '#334155',
    fontSize: 17,
    fontWeight: '700',
  },
  quantity: {
    color: '#1E293B',
    fontSize: 12,
    fontWeight: '800',
  },
  removeButton: {
    marginLeft: 8,
    paddingHorizontal: 3,
  },
  removeText: {
    color: '#94A3B8',
    fontSize: 22,
  },
  loader: {
    marginVertical: 35,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyEmoji: {
    fontSize: 38,
  },
  emptyTitle: {
    color: '#1E293B',
    fontSize: 17,
    fontWeight: '800',
    marginTop: 12,
  },
  emptyText: {
    color: '#94A3B8',
    fontSize: 13,
    marginTop: 6,
  },
  disclaimer: {
    color: '#94A3B8',
    fontSize: 10,
    textAlign: 'center',
    marginTop: 18,
  },
    compareButton: {
    backgroundColor: '#15803D',
    borderRadius: 17,
    padding: 17,
    marginBottom: 25,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  compareButtonDisabled: {
    opacity: 0.45,
  },
  compareButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '800',
  },
  compareButtonCaption: {
    color: '#DCFCE7',
    fontSize: 11,
    marginTop: 5,
  },
  compareButtonArrow: {
    color: '#FFFFFF',
    fontSize: 25,
    fontWeight: '700',
  },
});
