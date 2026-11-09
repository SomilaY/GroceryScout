import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';

import {
  compareBasket,
  getOrCreateBasket,
  type BasketComparisonResponse,
} from '@/services/baskets';

export default function BasketCompareScreen() {
  const router = useRouter();

  const [result, setResult] =
    useState<BasketComparisonResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function loadComparison() {
    setLoading(true);
    setError('');

    try {
      const basket = await getOrCreateBasket();
      const comparison = await compareBasket(basket.id);
      setResult(comparison);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Unable to compare your basket.'
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadComparison();
  }, []);

  const formatPrice = (cents: number | null) => {
    if (cents === null) return 'Unavailable';
    return `R${(cents / 100).toFixed(2)}`;
  };

  const cheapest = result?.cheapest_retailer ?? null;
    const completeComparisons =
    result?.comparisons.filter(
      (store) => store.complete && store.total_cents !== null
    ) ?? [];

  const mostExpensive = completeComparisons.reduce<
    (typeof completeComparisons)[number] | null
  >((highest, store) => {
    if (!highest || store.total_cents! > highest.total_cents!) {
      return store;
    }

    return highest;
  }, null);

  const savings =
    cheapest && mostExpensive && mostExpensive.total_cents !== null
      ? mostExpensive.total_cents - cheapest.total_cents
      : 0;

        const rankedComparisons = [...completeComparisons].sort(
    (a, b) => a.total_cents! - b.total_cents!
  );

  const highestTotal = Math.max(
    ...rankedComparisons.map((store) => store.total_cents ?? 0),
    1
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.content}
      >
        <Pressable
          onPress={() => router.back()}
          style={styles.backButton}
        >
          <Text style={styles.backText}>‹  My list</Text>
        </Pressable>

        <Text style={styles.eyebrow}>SMART SHOPPING</Text>
        <Text style={styles.title}>Compare your basket</Text>
        <Text style={styles.subtitle}>
          Find out where your entire shopping list costs less.
        </Text>

        {loading ? (
          <ActivityIndicator
            size="large"
            color="#16A34A"
            style={styles.loader}
          />
        ) : error ? (
          <View style={styles.messageCard}>
            <Text style={styles.messageTitle}>
              Couldn't compare your basket
            </Text>
            <Text style={styles.messageText}>{error}</Text>
            <Pressable
              onPress={loadComparison}
              style={styles.retryButton}
            >
              <Text style={styles.retryText}>Try again</Text>
            </Pressable>
          </View>
        ) : !result || result.comparisons.length === 0 ? (
          <View style={styles.messageCard}>
            <Text style={styles.emptyEmoji}>🛒</Text>
            <Text style={styles.messageTitle}>
              No comparison available
            </Text>
            <Text style={styles.messageText}>
              Add some products to your shopping list before comparing prices.
            </Text>
            <Pressable
              onPress={() => router.back()}
              style={styles.retryButton}
            >
              <Text style={styles.retryText}>Back to my list</Text>
            </Pressable>
          </View>
        ) : (
          <>
            {cheapest && (
              <LinearGradient
                colors={['#15803D', '#22C55E']}
                style={styles.winnerCard}
              >
                <Text style={styles.winnerLabel}>
                  CHEAPEST COMPLETE BASKET
                </Text>
                <Text style={styles.winnerName}>
                  {cheapest.name}
                </Text>
                <Text style={styles.winnerPrice}>
                  {formatPrice(cheapest.total_cents)}
                </Text>
                <Text style={styles.winnerDescription}>
                  Your entire basket costs less here.
                </Text>
              </LinearGradient>
            )}

            {cheapest && mostExpensive && savings > 0 && (
              <View style={styles.savingsCard}>
                <Text style={styles.savingsLabel}>
                  POTENTIAL SAVINGS
                </Text>
                <Text style={styles.savingsAmount}>
                  {formatPrice(savings)}
                </Text>
                <Text style={styles.savingsDescription}>
                  You save this amount by shopping at {cheapest.name}
                  instead of {mostExpensive.retailer}.
                </Text>
              </View>
            )}

            {rankedComparisons.length > 0 && (
              <View style={styles.chartCard}>
                <Text style={styles.chartTitle}>
                  Basket price ranking
                </Text>
                <Text style={styles.chartSubtitle}>
                  Compare the total cost at each retailer.
                </Text>

                {rankedComparisons.map((store, index) => {
                  const isCheapest =
                    store.retailer === cheapest?.name;

                  const barWidth = `${
                    Math.max(
                      (store.total_cents! / highestTotal) * 100,
                      2
                    )
                  }%` as `${number}%`;

                  return (
                    <View
                      key={store.retailer}
                      style={styles.chartRow}
                    >
                      <View style={styles.chartLabelRow}>
                        <Text style={styles.chartRetailer}>
                          {index + 1}. {store.retailer}
                        </Text>
                        <Text
                          style={[
                            styles.chartPrice,
                            isCheapest && styles.chartBestPrice,
                          ]}
                        >
                          {formatPrice(store.total_cents)}
                        </Text>
                      </View>

                      <View style={styles.chartTrack}>
                        <View
                          style={[
                            styles.chartBar,
                            { width: barWidth },
                            isCheapest && styles.chartBestBar,
                          ]}
                        />
                      </View>
                    </View>
                  );
                })}
              </View>
            )}

            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>
                Retailer comparison
              </Text>
              <Text style={styles.sectionCaption}>
                {result.comparisons.length} stores
              </Text>
            </View>

            {result.comparisons.map((store) => {
              const isCheapest =
                cheapest?.name === store.retailer;

              return (
                <View
                  key={store.retailer}
                  style={[
                    styles.storeCard,
                    isCheapest && styles.bestStoreCard,
                  ]}
                >
                  <View style={styles.storeHeader}>
                    <View style={styles.storeIdentity}>
                      <View
                        style={[
                          styles.storeIcon,
                          isCheapest && styles.bestStoreIcon,
                        ]}
                      >
                        <Text style={styles.storeInitial}>
                          {store.retailer.charAt(0)}
                        </Text>
                      </View>

                      <View style={styles.storeNameContainer}>
                        <Text style={styles.storeName}>
                          {store.retailer}
                        </Text>
                        <Text style={styles.storeStatus}>
                          {store.complete
                            ? 'Complete basket'
                            : 'Incomplete basket'}
                        </Text>
                      </View>
                    </View>

                    <View style={styles.storePriceContainer}>
                      <Text style={styles.storePrice}>
                        {formatPrice(store.total_cents)}
                      </Text>
                      {isCheapest && (
                        <Text style={styles.bestLabel}>
                          BEST PRICE
                        </Text>
                      )}
                    </View>
                  </View>

                  <View style={styles.storeDivider} />

                  <Text style={styles.detailHeading}>
                    Available products ({store.items.length})
                  </Text>

                  {store.items.map((item, index) => (
                    <View
                      key={`${store.retailer}-${item.product_name}-${index}`}
                      style={styles.productRow}
                    >
                      <View style={styles.productDetails}>
                        <Text style={styles.productName}>
                          {item.product_name}
                        </Text>
                                               <Text style={styles.productQuantity}>
                          {item.quantity} × {formatPrice(item.unit_price_cents)} each
                        </Text>
                        {!item.fresh && (
                          <Text style={styles.staleWarning}>
                            Price may be outdated
                          </Text>
                        )}
                      </View>

                      <Text style={styles.productPrice}>
                        {formatPrice(item.line_total_cents)}
                      </Text>
                    </View>
                  ))}

                  {store.missing_items.length > 0 && (
                    <View style={styles.warningSection}>
                      <Text style={styles.warningTitle}>
                        Missing products ({store.missing_items.length})
                      </Text>
                      {store.missing_items.map((name) => (
                        <Text
                          key={name}
                          style={styles.warningText}
                        >
                          • {name}
                        </Text>
                      ))}
                    </View>
                  )}

                  {store.stale_items.length > 0 && (
                    <View style={styles.staleSection}>
                      <Text style={styles.staleTitle}>
                        Outdated prices ({store.stale_items.length})
                      </Text>
                      {store.stale_items.map((item, index) => (
                        <Text
                          key={`${item.product_name}-${index}`}
                          style={styles.staleText}
                        >
                          {item.product_name}: last recorded at{' '}
                          {formatPrice(item.last_price_cents)}
                        </Text>
                      ))}
                    </View>
                  )}
                </View>
              );
            })}

            <View style={styles.tipCard}>
              <Text style={styles.tipIcon}>💡</Text>
              <View style={styles.tipContent}>
                <Text style={styles.tipTitle}>
                  Shop smarter
                </Text>
                <Text style={styles.tipText}>
                  A complete basket includes every product on your list.
                  Check missing products and outdated prices before deciding
                  where to shop.
                </Text>
              </View>
            </View>

            <Text style={styles.disclaimer}>
              Prices are based on the latest available retailer listings
              and are not guaranteed to be live.
            </Text>
          </>
        )}

        <Pressable
          onPress={loadComparison}
          disabled={loading}
          style={styles.refreshButton}
        >
          <Text style={styles.refreshText}>
            ↻  Refresh comparison
          </Text>
        </Pressable>
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
    paddingTop: 12,
    paddingBottom: 60,
  },
  backButton: {
    alignSelf: 'flex-start',
    paddingVertical: 10,
    marginBottom: 20,
  },
  backText: {
    color: '#15803D',
    fontSize: 15,
    fontWeight: '700',
  },
  eyebrow: {
    color: '#22C55E',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 8,
  },
  title: {
    color: '#1E293B',
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: -0.7,
  },
  subtitle: {
    color: '#64748B',
    fontSize: 14,
    marginTop: 7,
    marginBottom: 25,
    lineHeight: 21,
  },
  loader: {
    marginTop: 70,
  },
  winnerCard: {
    borderRadius: 24,
    padding: 23,
    marginBottom: 28,
  },
  winnerLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1.4,
  },
  winnerName: {
    color: '#FFFFFF',
    fontSize: 23,
    fontWeight: '900',
    marginTop: 12,
  },
  winnerPrice: {
    color: '#FFFFFF',
    fontSize: 37,
    fontWeight: '900',
    marginTop: 5,
  },
  winnerDescription: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 12,
    marginTop: 5,
  },
  savingsCard: {
    backgroundColor: '#DCFCE7',
    borderRadius: 18,
    padding: 18,
    marginBottom: 25,
    borderWidth: 1,
    borderColor: '#86EFAC',
  },
  savingsLabel: {
    color: '#15803D',
    fontSize: 10,
    fontWeight: '900',
    letterSpacing: 1.2,
  },
  savingsAmount: {
    color: '#166534',
    fontSize: 30,
    fontWeight: '900',
    marginTop: 7,
  },
  savingsDescription: {
    color: '#166534',
    fontSize: 12,
    lineHeight: 18,
    marginTop: 5,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 13,
  },
  sectionTitle: {
    color: '#1E293B',
    fontSize: 18,
    fontWeight: '800',
  },
  sectionCaption: {
    color: '#94A3B8',
    fontSize: 12,
  },
  storeCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 16,
    marginBottom: 13,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  bestStoreCard: {
    borderColor: '#86EFAC',
    backgroundColor: '#F0FDF4',
  },
  storeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  storeIdentity: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  storeIcon: {
    width: 43,
    height: 43,
    borderRadius: 14,
    backgroundColor: '#64748B',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 11,
  },
  bestStoreIcon: {
    backgroundColor: '#15803D',
  },
  storeInitial: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '900',
  },
  storeNameContainer: {
    flex: 1,
  },
  storeName: {
    color: '#1E293B',
    fontSize: 14,
    fontWeight: '800',
  },
  storeStatus: {
    color: '#94A3B8',
    fontSize: 10,
    marginTop: 4,
  },
  storePriceContainer: {
    alignItems: 'flex-end',
  },
  storePrice: {
    color: '#1E293B',
    fontSize: 17,
    fontWeight: '900',
  },
  bestLabel: {
    color: '#15803D',
    fontSize: 9,
    fontWeight: '900',
    marginTop: 4,
  },
  storeDivider: {
    height: 1,
    backgroundColor: '#E2E8F0',
    marginVertical: 14,
  },
  detailHeading: {
    color: '#475569',
    fontSize: 11,
    fontWeight: '800',
    marginBottom: 10,
  },
  productRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 11,
  },
  productDetails: {
    flex: 1,
    paddingRight: 10,
  },
  productName: {
    color: '#1E293B',
    fontSize: 12,
    fontWeight: '700',
  },
  productQuantity: {
    color: '#94A3B8',
    fontSize: 10,
    marginTop: 3,
  },
  productPrice: {
    color: '#334155',
    fontSize: 12,
    fontWeight: '800',
  },
  staleWarning: {
    color: '#D97706',
    fontSize: 10,
    marginTop: 3,
  },
  warningSection: {
    backgroundColor: '#FFF7ED',
    borderRadius: 12,
    padding: 12,
    marginTop: 8,
  },
  warningTitle: {
    color: '#C2410C',
    fontSize: 11,
    fontWeight: '800',
    marginBottom: 6,
  },
  warningText: {
    color: '#9A3412',
    fontSize: 11,
    marginTop: 3,
  },
  staleSection: {
    backgroundColor: '#FFFBEB',
    borderRadius: 12,
    padding: 12,
    marginTop: 8,
  },
  staleTitle: {
    color: '#B45309',
    fontSize: 11,
    fontWeight: '800',
    marginBottom: 6,
  },
  staleText: {
    color: '#92400E',
    fontSize: 11,
    marginTop: 3,
  },
  messageCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 23,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    marginTop: 20,
  },
  emptyEmoji: {
    fontSize: 36,
    marginBottom: 12,
  },
  messageTitle: {
    color: '#1E293B',
    fontSize: 17,
    fontWeight: '800',
    textAlign: 'center',
  },
  messageText: {
    color: '#64748B',
    fontSize: 12,
    lineHeight: 19,
    textAlign: 'center',
    marginTop: 8,
  },
  retryButton: {
    backgroundColor: '#DCFCE7',
    borderRadius: 12,
    paddingHorizontal: 18,
    paddingVertical: 11,
    marginTop: 17,
  },
  retryText: {
    color: '#15803D',
    fontSize: 12,
    fontWeight: '800',
  },
  tipCard: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    padding: 17,
    borderRadius: 20,
    marginTop: 15,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  tipIcon: {
    fontSize: 24,
    marginRight: 13,
  },
  tipContent: {
    flex: 1,
  },
  tipTitle: {
    color: '#1E293B',
    fontSize: 14,
    fontWeight: '800',
  },
  tipText: {
    color: '#64748B',
    fontSize: 12,
    lineHeight: 18,
    marginTop: 5,
  },
  disclaimer: {
    color: '#94A3B8',
    fontSize: 10,
    textAlign: 'center',
    lineHeight: 16,
    marginTop: 18,
  },
  refreshButton: {
    alignSelf: 'center',
    padding: 14,
    marginTop: 12,
  },
  refreshText: {
    color: '#15803D',
    fontSize: 13,
    fontWeight: '800',
  },
    chartCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 18,
    marginBottom: 25,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  chartTitle: {
    color: '#1E293B',
    fontSize: 16,
    fontWeight: '900',
  },
  chartSubtitle: {
    color: '#94A3B8',
    fontSize: 11,
    marginTop: 5,
    marginBottom: 20,
  },
  chartRow: {
    marginBottom: 17,
  },
  chartLabelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  chartRetailer: {
    color: '#334155',
    fontSize: 12,
    fontWeight: '700',
  },
  chartPrice: {
    color: '#64748B',
    fontSize: 12,
    fontWeight: '800',
  },
  chartBestPrice: {
    color: '#15803D',
  },
  chartTrack: {
    height: 11,
    backgroundColor: '#F1F5F9',
    borderRadius: 10,
    overflow: 'hidden',
  },
  chartBar: {
    height: 11,
    backgroundColor: '#94A3B8',
    borderRadius: 10,
  },
  chartBestBar: {
    backgroundColor: '#22C55E',
  },
});
