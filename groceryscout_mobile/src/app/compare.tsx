
import React from 'react';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import {
  fetchProduct,
  fetchPriceHistory,
  Product,
  PriceHistoryResponse,
} from '@/services/products';
import Svg, {
  Circle,
  Line,
  Polyline,
  Text as SvgText,
} from 'react-native-svg';

export default function CompareScreen() {
  const router = useRouter();
  const { productId } = useLocalSearchParams<{ productId: string }>();

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [history, setHistory] = useState<PriceHistoryResponse | null>(null);
const [historyLoading, setHistoryLoading] = useState(true);
const [historyError, setHistoryError] = useState<string | null>(null);
const [historyDays, setHistoryDays] = useState<7 | 30>(7);

  useEffect(() => {
    let cancelled = false;

    async function loadProduct() {
      if (!productId) {
        setError('No product was selected.');
        setLoading(false);
        return;
      }

      try {
        const result = await fetchProduct(Number(productId));

        if (!cancelled) {
          setProduct(result);
        }
      } catch {
        if (!cancelled) {
          setError('Unable to load this product. Please try again.');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    loadProduct();

    return () => {
      cancelled = true;
    };
  }, [productId]);

  useEffect(() => {
    let cancelled = false;

    async function loadPriceHistory() {
      if (!productId) {
        setHistoryLoading(false);
        return;
      }

      setHistoryLoading(true);
      setHistoryError(null);

      try {
        const result = await fetchPriceHistory(
          Number(productId),
          historyDays
        );

        if (!cancelled) {
          setHistory(result);
        }
      } catch {
        if (!cancelled) {
          setHistoryError('Unable to load price history.');
        }
      } finally {
        if (!cancelled) {
          setHistoryLoading(false);
        }
      }
    }

    loadPriceHistory();

    return () => {
      cancelled = true;
    };
  }, [productId, historyDays]);

  const chartData = (() => {
    if (!history) {
      return {
        dates: [] as string[],
        retailers: [] as { name: string; prices: Map<string, number> }[],
      };
    }

    // Collect all dates across retailers.
    const dateSet = new Set<string>();

    const retailers = history.retailers.map((retailer) => {
      const dailyPrices = new Map<string, number>();

      // Sort observations from oldest to newest.
      const sortedPrices = [...retailer.prices].sort(
        (a, b) =>
          new Date(a.observed_at).getTime() -
          new Date(b.observed_at).getTime()
      );

      sortedPrices.forEach((point) => {
        const date = new Date(point.observed_at)
          .toISOString()
          .slice(0, 10);

        // Keep the latest observation for each day.
        dailyPrices.set(date, point.price);
        dateSet.add(date);
      });

      return {
        name: retailer.retailer,
        prices: dailyPrices,
      };
    });

    return {
      dates: Array.from(dateSet).sort(),
      retailers,
    };
  })();

  const allChartPrices = chartData.retailers.flatMap((retailer) =>
    Array.from(retailer.prices.values())
  );

  const chartMin = allChartPrices.length
    ? Math.min(...allChartPrices)
    : 0;

  const chartMax = allChartPrices.length
    ? Math.max(...allChartPrices)
    : 0;

  const chartRange = Math.max(chartMax - chartMin, 1);

  const retailerColors: Record<string, string> = {
    Checkers: '#16A34A',
    'Pick n Pay': '#2563EB',
    Shoprite: '#EA580C',
    Woolworths: '#7C3AED',
  };

  const chartWidth = 320;
  const chartHeight = 190;

  const chartLeft = 48;
  const chartRight = 12;
  const chartTop = 16;
  const chartBottom = 30;

  const plotWidth = chartWidth - chartLeft - chartRight;
  const plotHeight = chartHeight - chartTop - chartBottom;

  const getChartX = (index: number) =>
    chartLeft +
    (chartData.dates.length <= 1
      ? plotWidth / 2
      : (index / (chartData.dates.length - 1)) * plotWidth);

  const getChartY = (price: number) =>
    chartTop + ((chartMax - price) / chartRange) * plotHeight;

  const formatChartDate = (date: string) =>
    new Date(`${date}T00:00:00`).toLocaleDateString('en-ZA', {
      day: 'numeric',
      month: 'short',
    });

  const chartTicks = [
    chartMin,
    (chartMin + chartMax) / 2,
    chartMax,
  ];

  const stores = product?.prices ?? [];

  const freshPrices = stores.filter((store) => store.fresh);

  const cheapest = freshPrices.length
    ? Math.min(...freshPrices.map((store) => store.price))
    : null;

  const mostExpensive = freshPrices.length
    ? Math.max(...freshPrices.map((store) => store.price))
    : null;

  const savings =
    cheapest !== null && mostExpensive !== null
      ? mostExpensive - cheapest
      : null;

  const categoryEmoji: Record<string, string> = {
    Dairy: '🥛',
    Bakery: '🍞',
    Pantry: '🛒',
    'Fresh produce': '🥑',
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <ActivityIndicator
          size="large"
          color="#15803D"
          style={{ flex: 1 }}
        />
      </SafeAreaView>
    );
  }

  if (error || !product) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 25 }}>
          <Text style={styles.productName}>
            {error ?? 'Product not found.'}
          </Text>
          <Pressable onPress={() => router.back()} style={styles.backButton}>
            <Text style={styles.backText}>‹  Go back</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.content}
      >
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>‹  Back</Text>
        </Pressable>

        <Text style={styles.eyebrow}>SMART SHOPPING</Text>
        <Text style={styles.title}>Price comparison</Text>
        <Text style={styles.subtitle}>
          See where your groceries cost less.
        </Text>

        <View style={styles.productCard}>
  <View style={styles.productImage}>
    <Text style={styles.productEmoji}>
      {categoryEmoji[product.category ?? ''] ?? '🛒'}
    </Text>
  </View>

  <View style={styles.productInfo}>
    <Text style={styles.brand}>
      {product.brand?.toUpperCase() ?? 'GROCERY PRODUCT'}
    </Text>

    <Text style={styles.productName}>
      {product.name}
    </Text>

    <Text style={styles.detail}>
      {[product.quantity, product.unit, product.category]
        .filter(Boolean)
        .join(' · ')}
    </Text>
  </View>
</View>

        <LinearGradient
          colors={['#16A34A', '#22C55E']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.savingsCard}
        >
          <Text style={styles.savingsLabel}>POTENTIAL SAVING</Text>
          <Text style={styles.savingsAmount}>
  {savings !== null ? `R${savings.toFixed(2)}` : 'N/A'}
</Text>
        <Text style={styles.savingsDescription}>
  {savings !== null
    ? 'Difference between the lowest and highest fresh retailer prices.'
    : 'Not enough fresh retailer prices to calculate savings.'}
</Text>
        </LinearGradient>

        <View style={styles.resultsHeader}>
          <Text style={styles.sectionTitle}>Compare stores</Text>
          <Text style={styles.resultsCount}>
  {stores.length} {stores.length === 1 ? 'store' : 'stores'}
</Text>
        </View>

        {stores.map((store) => {
          const isCheapest =
            store.fresh && store.price === cheapest;

          return (
            <View
              key={store.retailer}
              style={[
                styles.storeCard,
                isCheapest && styles.bestStoreCard,
              ]}
            >
              <View style={styles.storeLeft}>
                <View
                  style={[
                    styles.storeIcon,
                    {
                      backgroundColor: isCheapest ? '#15803D' : '#64748B',
                    },
                  ]}
                >
                  <Text style={styles.storeInitial}>
                    {store.retailer.charAt(0)}
                  </Text>
                </View>

                <View>
                  <Text style={styles.storeName}>
                    {store.retailer}
                  </Text>
                  {isCheapest ? (
                    <Text style={styles.bestLabel}>BEST PRICE</Text>
                  ) : (
                    <Text style={styles.storeCaption}>
                      {store.fresh ? 'Fresh price' : 'Price may be outdated'}
                    </Text>
                  )}
                </View>
              </View>

              <View style={styles.priceContainer}>
                <Text style={styles.price}>
                  R{store.price.toFixed(2)}
                </Text>

                {isCheapest && (
                  <Text style={styles.cheapestText}>Cheapest</Text>
                )}
              </View>
            </View>
          );
        })}

        {/* PRICE HISTORY */}
        <View style={styles.historyCard}>
          <View style={styles.historyHeader}>
            <View>
              <Text style={styles.historyTitle}>Price history</Text>
              <Text style={styles.historySubtitle}>
                Track how prices change over time
              </Text>
            </View>

            <View style={styles.historyFilters}>
              {[7, 30].map((days) => (
                <Pressable
                  key={days}
                  style={[
                    styles.historyFilter,
                    historyDays === days && styles.historyFilterActive,
                  ]}
                  onPress={() => setHistoryDays(days as 7 | 30)}
                >
                  <Text
                    style={[
                      styles.historyFilterText,
                      historyDays === days && styles.historyFilterTextActive,
                    ]}
                  >
                    {days}D
                  </Text>
                </Pressable>
              ))}
            </View>
          </View>

          {historyLoading ? (
            <ActivityIndicator size="small" color="#16A34A" />
          ) : historyError ? (
            <Text style={styles.historyMessage}>{historyError}</Text>
          ) : chartData.dates.length === 0 ? (
            <Text style={styles.historyMessage}>
              No price history is available for this period yet.
            </Text>
          ) : (
            <>
              <Svg width={chartWidth} height={chartHeight}>
                {chartTicks.map((tick, index) => {
                  const y = getChartY(tick);

                  return (
                    <React.Fragment key={index}>
                      <Line
                        x1={chartLeft}
                        y1={y}
                        x2={chartWidth - chartRight}
                        y2={y}
                        stroke="#E5E7EB"
                        strokeWidth="1"
                      />
                      <SvgText
                        x={chartLeft - 8}
                        y={y + 4}
                        fontSize="10"
                        fill="#6B7280"
                        textAnchor="end"
                      >
                        R{tick.toFixed(0)}
                      </SvgText>
                    </React.Fragment>
                  );
                })}

                {chartData.dates.map((date, index) => {
                  if (
                    index !== 0 &&
                    index !== Math.floor((chartData.dates.length - 1) / 2) &&
                    index !== chartData.dates.length - 1
                  ) {
                    return null;
                  }

                  return (
                    <SvgText
                      key={date}
                      x={getChartX(index)}
                      y={chartHeight - 6}
                      fontSize="10"
                      fill="#6B7280"
                      textAnchor="middle"
                    >
                      {formatChartDate(date)}
                    </SvgText>
                  );
                })}

                {chartData.retailers.map((retailer) => {
                  const points = chartData.dates
                    .map((date, index) => {
                      const price = retailer.prices.get(date);

                      return price === undefined
                        ? null
                        : `${getChartX(index)},${getChartY(price)}`;
                    })
                    .filter(Boolean)
                    .join(' ');

                  if (!points) return null;

                  return (
                    <Polyline
                      key={retailer.name}
                      points={points}
                      fill="none"
                      stroke={retailerColors[retailer.name] ?? '#64748B'}
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  );
                })}

                {chartData.retailers.map((retailer) =>
                  chartData.dates.map((date, index) => {
                    const price = retailer.prices.get(date);

                    if (price === undefined) return null;

                    return (
                      <Circle
                        key={`${retailer.name}-${date}`}
                        cx={getChartX(index)}
                        cy={getChartY(price)}
                        r="3"
                        fill={retailerColors[retailer.name] ?? '#64748B'}
                      />
                    );
                  })
                )}
              </Svg>

              <View style={styles.historyLegend}>
                {chartData.retailers.map((retailer) => (
                  <View key={retailer.name} style={styles.historyLegendItem}>
                    <View
                      style={[
                        styles.historyLegendDot,
                        {
                          backgroundColor:
                            retailerColors[retailer.name] ?? '#64748B',
                        },
                      ]}
                    />
                    <Text style={styles.historyLegendText}>
                      {retailer.name}
                    </Text>
                  </View>
                ))}
              </View>

              <Text style={styles.historyDisclaimer}>
                Sample development data — not live retailer price history.
              </Text>
            </>
          )}
        </View>

        <View style={styles.tipCard}>
          <Text style={styles.tipIcon}>💡</Text>
          <View style={styles.tipContent}>
            <Text style={styles.tipTitle}>A little goes a long way</Text>
            <Text style={styles.tipText}>
              Comparing prices before shopping can help you make
              smarter spending decisions.
            </Text>
          </View>
        </View>

        <Text style={styles.disclaimer}>
          Prices are based on the latest available retailer listings.
          Stale prices may no longer be accurate. Prices are not
          guaranteed to be live.
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
    paddingTop: 12,
    paddingBottom: 110,
  },
  backButton: {
    alignSelf: 'flex-start',
    paddingVertical: 10,
    paddingRight: 15,
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
    fontSize: 29,
    fontWeight: '800',
    letterSpacing: -0.8,
  },
  subtitle: {
    color: '#64748B',
    fontSize: 14,
    marginTop: 7,
    marginBottom: 25,
  },
  productCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 22,
    padding: 15,
    marginBottom: 18,
    borderWidth: 1,
    borderColor: '#FFFFFF',
  },
  productImage: {
    width: 70,
    height: 75,
    borderRadius: 18,
    backgroundColor: '#F1F5F9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  productEmoji: {
    fontSize: 37,
  },
  productInfo: {
    marginLeft: 15,
  },
  brand: {
    color: '#22C55E',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1,
  },
  productName: {
    color: '#1E293B',
    fontSize: 16,
    fontWeight: '800',
    marginTop: 4,
  },
  detail: {
    color: '#94A3B8',
    fontSize: 12,
    marginTop: 5,
  },
  savingsCard: {
    borderRadius: 24,
    padding: 22,
    marginBottom: 29,
  },
  savingsLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  savingsAmount: {
    color: '#FFFFFF',
    fontSize: 37,
    fontWeight: '900',
    marginTop: 8,
  },
  savingsDescription: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 12,
    marginTop: 5,
    lineHeight: 18,
  },
  resultsHeader: {
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
  resultsCount: {
    color: '#94A3B8',
    fontSize: 12,
  },
  storeCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 19,
    padding: 14,
    marginBottom: 11,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  bestStoreCard: {
    borderColor: '#86EFAC',
    backgroundColor: '#F0FDF4',
  },
  storeLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  storeIcon: {
    width: 43,
    height: 43,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  storeInitial: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '900',
  },
  storeName: {
    color: '#1E293B',
    fontSize: 14,
    fontWeight: '800',
  },
  bestLabel: {
    color: '#15803D',
    fontSize: 9,
    fontWeight: '900',
    letterSpacing: 1,
    marginTop: 5,
  },
  storeCaption: {
    color: '#94A3B8',
    fontSize: 10,
    marginTop: 5,
  },
  priceContainer: {
    alignItems: 'flex-end',
  },
  price: {
    color: '#1E293B',
    fontSize: 17,
    fontWeight: '900',
  },
  cheapestText: {
    color: '#15803D',
    fontSize: 10,
    fontWeight: '700',
    marginTop: 4,
  },
  historyCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 18,
    marginTop: 20,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  historyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  historyTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#111827',
  },
  historySubtitle: {
    fontSize: 12,
    color: '#6B7280',
    marginTop: 4,
  },
  historyFilters: {
    flexDirection: 'row',
    backgroundColor: '#F3F4F6',
    borderRadius: 10,
    padding: 3,
  },
  historyFilter: {
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 8,
  },
  historyFilterActive: {
    backgroundColor: '#16A34A',
  },
  historyFilterText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6B7280',
  },
  historyFilterTextActive: {
    color: '#FFFFFF',
  },
  historyMessage: {
    fontSize: 13,
    color: '#6B7280',
    textAlign: 'center',
    paddingVertical: 25,
  },
  historyLegend: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 14,
    marginTop: 12,
  },
  historyLegendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  historyLegendDot: {
    width: 9,
    height: 9,
    borderRadius: 5,
  },
  historyLegendText: {
    fontSize: 11,
    color: '#4B5563',
  },
  historyDisclaimer: {
    fontSize: 10,
    color: '#9CA3AF',
    marginTop: 14,
    textAlign: 'center',
  },
  tipCard: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    padding: 17,
    borderRadius: 20,
    marginTop: 17,
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
    marginTop: 20,
  },
});
