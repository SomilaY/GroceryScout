import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { useFocusEffect } from 'expo-router';
import {
  compareBasket,
  getOrCreateBasket,
  type BasketComparisonResponse,
} from '@/services/baskets';
import {
  fetchProducts,
  fetchPriceHistory,
  Product,
} from '@/services/products';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';

const COLORS = {
  background: '#F8FAFC',
  green: '#22C55E',
  darkGreen: '#15803D',
  red: '#DC2626',
  text: '#1E293B',
  muted: '#64748B',
  white: '#FFFFFF',
  border: '#E2E8F0',
};

const tips = [
  {
    icon: '🛒',
    title: 'Compare your entire basket',
    description:
      'Shopping at the cheapest store for each product could help reduce your overall grocery bill.',
  },
  {
    icon: '🥛',
    title: 'Look for better dairy prices',
    description:
      'Milk and other dairy products can have different prices across retailers. Compare before buying.',
  },
  {
    icon: '📋',
    title: 'Stick to your shopping list',
    description:
      'Planning your shopping before visiting a store can help avoid unnecessary purchases.',
  },
];

export default function InsightsScreen() {
    const [products, setProducts] = useState<Product[]>([]);
  const [loadingProducts, setLoadingProducts] = useState(true);
  const [productsError, setProductsError] = useState(false);
    const [priceMovements, setPriceMovements] = useState<
    {
      id: string;
      productName: string;
      retailer: string;
      previousPrice: number;
      currentPrice: number;
      change: number;
      percentage: number;
      direction: 'increased' | 'decreased' | 'stable';
    }[]
  >([]);

  const [loadingMovements, setLoadingMovements] = useState(false);
  const [movementsError, setMovementsError] = useState(false);
    const [basketComparison, setBasketComparison] =
    useState<BasketComparisonResponse | null>(null);

  const [loadingBasket, setLoadingBasket] = useState(true);
  const [basketError, setBasketError] = useState(false);
  const [basketEmpty, setBasketEmpty] = useState(false);

  useEffect(() => {
    let isActive = true;

    async function loadProducts() {
      try {
        const response = await fetchProducts();

        if (isActive) {
          setProducts(response.products);
          setProductsError(false);
        }
      } catch {
        if (isActive) {
          setProductsError(true);
        }
      } finally {
        if (isActive) {
          setLoadingProducts(false);
        }
      }
    }

    loadProducts();

    return () => {
      isActive = false;
    };
  }, []);

    useFocusEffect(
    useCallback(() => {
      let isActive = true;

      async function loadBasketInsights() {
        setLoadingBasket(true);
        setBasketError(false);
        setBasketEmpty(false);

        try {
          const basket = await getOrCreateBasket();

          if (!isActive) return;

          if (basket.items.length === 0) {
            setBasketComparison(null);
            setBasketEmpty(true);
            return;
          }

          const comparison = await compareBasket(basket.id);

          if (isActive) {
            setBasketComparison(comparison);
          }
        } catch {
          if (isActive) {
            setBasketError(true);
          }
        } finally {
          if (isActive) {
            setLoadingBasket(false);
          }
        }
      }

      loadBasketInsights();

      return () => {
        isActive = false;
      };
    }, [])
  );

  useEffect(() => {
    if (products.length === 0) {
      return;
    }

    let isActive = true;

    async function loadPriceMovements() {
      setLoadingMovements(true);
      setMovementsError(false);

      try {
        const results = await Promise.all(
          products.map(async (product) => {
            try {
              const history = await fetchPriceHistory(product.id, 30);

              return history.retailers.flatMap((retailer) => {
                const observations = [...retailer.prices]
                  .filter(
                    (point) =>
                      Number.isFinite(point.price) &&
                      point.price > 0
                  )
                  .sort(
                    (a, b) =>
                      new Date(a.observed_at).getTime() -
                      new Date(b.observed_at).getTime()
                  );

                if (observations.length < 2) {
                  return [];
                }

                const previousPrice = observations[0].price;
                const currentPrice =
                  observations[observations.length - 1].price;

                const change = currentPrice - previousPrice;
                const percentage =
                  (change / previousPrice) * 100;

                const direction: 'stable' | 'increased' | 'decreased' =
                  Math.abs(change) < 0.01
                    ? 'stable'
                    : change > 0
                      ? 'increased'
                      : 'decreased';

                return [{
                  id: `${product.id}-${retailer.retailer}`,
                  productName: product.name,
                  retailer: retailer.retailer,
                  previousPrice,
                  currentPrice,
                  change,
                  percentage,
                  direction,
                }];
              });
            } catch {
              return [];
            }
          })
        );

        if (isActive) {
          const movements = results
            .flat()
            .sort(
              (a, b) =>
                Math.abs(b.change) - Math.abs(a.change)
            );

          setPriceMovements(movements);
        }
      } catch {
        if (isActive) {
          setMovementsError(true);
        }
      } finally {
        if (isActive) {
          setLoadingMovements(false);
        }
      }
    }

    loadPriceMovements();

    return () => {
      isActive = false;
    };
  }, [products]);

  const priceOpportunities = useMemo(() => {
    return products
      .flatMap((product) => {
        const prices = product.prices.filter(
          (price) => price.fresh && Number.isFinite(price.price)
        );

        if (prices.length < 2) {
          return [];
        }

        const sortedPrices = [...prices].sort(
          (a, b) => a.price - b.price
        );

        const cheapest = sortedPrices[0];
        const mostExpensive = sortedPrices[sortedPrices.length - 1];

        const difference = mostExpensive.price - cheapest.price;

        return [{
          id: product.id,
          name: product.name,
          brand: product.brand,
          category: product.category || 'Other',
          difference,
          cheapestRetailer: cheapest.retailer,
          cheapestPrice: cheapest.price,
          highestPrice: mostExpensive.price,
        }];
      })
      .sort((a, b) => b.difference - a.difference);
  }, [products]);

  const totalPotentialSavings = useMemo(
    () =>
      priceOpportunities.reduce(
        (total, product) => total + product.difference,
        0
      ),
    [priceOpportunities]
  );

  const categorySavings = useMemo(() => {
    const totals: Record<string, number> = {};

    priceOpportunities.forEach((product) => {
      totals[product.category] =
        (totals[product.category] || 0) + product.difference;
    });

    const maximum = Math.max(0, ...Object.values(totals));

    return Object.entries(totals)
      .map(([name, saving]) => ({
        name,
        saving,
        percentage: maximum > 0 ? (saving / maximum) * 100 : 0,
      }))
      .sort((a, b) => b.saving - a.saving);
  }, [priceOpportunities]);

    const basketSavings = useMemo(() => {
    if (!basketComparison) {
      return null;
    }

    const completeComparisons = basketComparison.comparisons
      .filter(
        (comparison) =>
          comparison.complete &&
          comparison.total_cents !== null
      )
      .sort(
        (a, b) =>
          (a.total_cents ?? 0) - (b.total_cents ?? 0)
      );

    if (completeComparisons.length === 0) {
      return null;
    }

    const cheapest = completeComparisons[0];
    const mostExpensive =
      completeComparisons[completeComparisons.length - 1];

    return {
      cheapestRetailer: cheapest.retailer,
      cheapestTotal: (cheapest.total_cents ?? 0) / 100,
      mostExpensiveRetailer: mostExpensive.retailer,
      mostExpensiveTotal:
        (mostExpensive.total_cents ?? 0) / 100,
      savings:
        ((mostExpensive.total_cents ?? 0) -
          (cheapest.total_cents ?? 0)) /
        100,
      comparisons: completeComparisons.map((comparison) => ({
        retailer: comparison.retailer,
        total: (comparison.total_cents ?? 0) / 100,
      })),
    };
  }, [basketComparison]);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.header}>
        <View>
          <Text style={styles.eyebrow}>YOUR MONEY, SMARTER</Text>
          <Text style={styles.heading}>Savings insights</Text>
          <Text style={styles.subtitle}>
            Small changes. Bigger savings.
          </Text>
        </View>

        <View style={styles.aiBadge}>
          <Text style={styles.aiBadgeText}>✦ AI</Text>
        </View>
      </View>

      <LinearGradient
        colors={['#166534', '#15803D', '#22C55E']}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.heroCard}
      >
        <Text style={styles.heroLabel}>
          TOTAL POTENTIAL PRICE DIFFERENCE
        </Text>

        <Text style={styles.heroAmount}>
          {loadingProducts || productsError
            ? '—'
            : `R${totalPotentialSavings.toFixed(2)}`}
        </Text>

        <Text style={styles.heroDescription}>
          Combined price differences across products with at least two fresh retailer prices.
        </Text>

        <View style={styles.heroDivider} />

        <View style={styles.heroFooter}>
          <Text style={styles.heroFooterLabel}>
            Based on available API prices
          </Text>
          <Text style={styles.heroSparkle}>✦</Text>
        </View>
      </LinearGradient>

      <View style={styles.basketInsightsSection}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>
            Your basket savings
          </Text>
          <Text style={styles.sectionSubtitle}>
            BASKET COMPARISON
          </Text>
        </View>

        {loadingBasket ? (
          <View style={styles.basketInsightsCard}>
            <Text style={styles.basketMessage}>
              Comparing your basket prices...
            </Text>
          </View>
        ) : basketError ? (
          <View style={styles.basketInsightsCard}>
            <Text style={styles.basketMessage}>
              Could not load your basket comparison.
            </Text>
          </View>
        ) : basketEmpty ? (
          <View style={styles.basketInsightsCard}>
            <Text style={styles.basketMessage}>
              Your shopping list is empty. Add groceries to see your
              potential basket savings.
            </Text>
          </View>
        ) : !basketSavings ? (
          <View style={styles.basketInsightsCard}>
            <Text style={styles.basketMessage}>
              No retailer currently has prices for every item in your
              basket. Try again when more prices are available.
            </Text>
          </View>
        ) : (
          <View style={styles.basketInsightsCard}>
            <Text style={styles.basketSavingsLabel}>
              POTENTIAL BASKET SAVINGS
            </Text>

            <Text style={styles.basketSavingsAmount}>
              R{basketSavings.savings.toFixed(2)}
            </Text>

            <Text style={styles.basketMessage}>
              Difference between the cheapest and most expensive
              complete basket.
            </Text>

            <View style={styles.basketDivider} />

            <View style={styles.basketRetailerRow}>
              <View style={styles.basketRetailerInfo}>
                <Text style={styles.basketRetailerLabel}>
                  Cheapest complete basket
                </Text>
                <Text style={styles.basketRetailerName}>
                  {basketSavings.cheapestRetailer}
                </Text>
              </View>

              <Text style={styles.basketRetailerPrice}>
                R{basketSavings.cheapestTotal.toFixed(2)}
              </Text>
            </View>

            <View style={styles.basketRetailerRow}>
              <View style={styles.basketRetailerInfo}>
                <Text style={styles.basketRetailerLabel}>
                  Most expensive complete basket
                </Text>
                <Text style={styles.basketRetailerName}>
                  {basketSavings.mostExpensiveRetailer}
                </Text>
              </View>

              <Text style={styles.basketRetailerPrice}>
                R{basketSavings.mostExpensiveTotal.toFixed(2)}
              </Text>
            </View>

            <View style={styles.basketDivider} />

            <Text style={styles.basketRetailerLabel}>
              Complete basket comparisons
            </Text>

            {basketSavings.comparisons.map((comparison) => (
              <View
                key={comparison.retailer}
                style={styles.basketComparisonRow}
              >
                <Text style={styles.basketComparisonName}>
                  {comparison.retailer}
                </Text>

                <Text style={styles.basketComparisonPrice}>
                  R{comparison.total.toFixed(2)}
                </Text>
              </View>
            ))}
          </View>
        )}
      </View>
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Biggest price differences</Text>
        <Text style={styles.sectionSubtitle}>LIVE API DATA</Text>
      </View>

      <View style={styles.opportunitiesCard}>
        {loadingProducts ? (
          <Text style={styles.opportunityMessage}>
            Loading product prices...
          </Text>
        ) : productsError ? (
          <Text style={styles.opportunityMessage}>
            Could not load prices. Please try again later.
          </Text>
        ) : priceOpportunities.length === 0 ? (
          <Text style={styles.opportunityMessage}>
            No products with two or more fresh retailer prices are available yet.
          </Text>
        ) : (
          priceOpportunities.slice(0, 5).map((product) => (
            <View key={product.id} style={styles.opportunityItem}>
              <View style={styles.opportunityTop}>
                <View style={styles.opportunityProduct}>
                  <Text style={styles.opportunityName}>
                    {product.name}
                  </Text>
                  {product.brand ? (
                    <Text style={styles.opportunityBrand}>
                      {product.brand}
                    </Text>
                  ) : null}
                </View>

                <Text style={styles.opportunitySaving}>
                  R{product.difference.toFixed(2)}
                </Text>
              </View>

              <Text style={styles.opportunityDetail}>
                Cheapest: {product.cheapestRetailer} at R
                {product.cheapestPrice.toFixed(2)}
              </Text>

              <Text style={styles.opportunityDetail}>
                Highest price: R{product.highestPrice.toFixed(2)}
              </Text>
            </View>
          ))
        )}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>30-Day Price Movements</Text>
        <Text style={styles.sectionSubtitle}>
          How recorded retailer prices have changed over the last 30 days
        </Text>

        {loadingMovements ? (
          <Text style={styles.emptyText}>Loading price movements...</Text>
        ) : movementsError ? (
          <Text style={styles.emptyText}>
            Could not load price movements.
          </Text>
        ) : priceMovements.length === 0 ? (
          <Text style={styles.emptyText}>
            Not enough price history yet. Products need at least two recorded
            prices at a retailer.
          </Text>
        ) : (
          priceMovements.map((movement) => {
            const isIncrease = movement.direction === 'increased';
            const isDecrease = movement.direction === 'decreased';

            const movementColor = isIncrease
              ? COLORS.red
              : isDecrease
                ? COLORS.green
                : COLORS.muted;

            return (
              <View key={movement.id} style={styles.movementCard}>
                <View style={styles.movementInfo}>
                  <Text style={styles.movementProduct}>
                    {movement.productName}
                  </Text>
                  <Text style={styles.movementRetailer}>
                    {movement.retailer}
                  </Text>
                  <Text style={styles.movementPrices}>
                    R{movement.previousPrice.toFixed(2)} → R
                    {movement.currentPrice.toFixed(2)}
                  </Text>
                </View>

                <View style={styles.movementResult}>
                  <Text
                    style={[
                      styles.movementChange,
                      { color: movementColor },
                    ]}
                  >
                    {movement.change > 0 ? '+' : ''}
                    R{movement.change.toFixed(2)}
                  </Text>
                  <Text
                    style={[
                      styles.movementPercentage,
                      { color: movementColor },
                    ]}
                  >
                    {movement.percentage > 0 ? '+' : ''}
                    {movement.percentage.toFixed(1)}%
                  </Text>
                  <Text
                    style={[
                      styles.movementDirection,
                      { color: movementColor },
                    ]}
                  >
                    {movement.direction}
                  </Text>
                </View>
              </View>
            );
          })
        )}
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Your savings overview</Text>
        <Text style={styles.sectionSubtitle}>API CALCULATED</Text>
      </View>

      <View style={styles.metricsRow}>
        <BlurView intensity={45} tint="light" style={styles.metricCard}>
          <Text style={styles.metricIcon}>💰</Text>
          <Text style={styles.metricValue}>
            {loadingProducts || productsError
              ? '—'
              : `R${totalPotentialSavings.toFixed(2)}`}
          </Text>
          <Text style={styles.metricLabel}>Potential price gaps</Text>
        </BlurView>

        <BlurView intensity={45} tint="light" style={styles.metricCard}>
          <Text style={styles.metricIcon}>🔍</Text>
          <Text style={styles.metricValue}>
            {loadingProducts || productsError
              ? '—'
              : priceOpportunities.length}
          </Text>
          <Text style={styles.metricLabel}>Products compared</Text>
        </BlurView>
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Savings by category</Text>
      </View>

      <View style={styles.categoryCard}>
        {categorySavings.map((category) => (
          <View key={category.name} style={styles.categoryItem}>
            <View style={styles.categoryTop}>
              <Text style={styles.categoryName}>{category.name}</Text>
              <Text style={styles.categorySaving}>
                R{category.saving.toFixed(2)}
              </Text>
            </View>

            <View style={styles.progressBackground}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${category.percentage}%` },
                ]}
              />
            </View>
          </View>
        ))}

        <View style={styles.categoryFooter}>
          <Text style={styles.categoryFooterLabel}>
            Potential category savings
          </Text>
          <Text style={styles.categoryFooterValue}>
            {loadingProducts || productsError
              ? '—'
              : `R${totalPotentialSavings.toFixed(2)}`}
          </Text>
        </View>
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Smart shopping tips</Text>
        <Text style={styles.sectionSubtitle}>AI INSIGHTS</Text>
      </View>

      {tips.map((tip) => (
        <View key={tip.title} style={styles.tipCard}>
          <View style={styles.tipIconContainer}>
            <Text style={styles.tipIcon}>{tip.icon}</Text>
          </View>

          <View style={styles.tipContent}>
            <Text style={styles.tipTitle}>{tip.title}</Text>
            <Text style={styles.tipDescription}>
              {tip.description}
            </Text>
          </View>
        </View>
      ))}

      <View style={styles.disclaimer}>
        <Text style={styles.disclaimerText}>
          API-calculated price differences are estimates of potential savings,
          not confirmed savings. Retailer prices are currently demonstration
          data, not verified live retailer feeds.
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 65,
    paddingBottom: 40,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 25,
  },
  eyebrow: {
    color: COLORS.darkGreen,
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 8,
  },
  heading: {
    color: COLORS.text,
    fontSize: 29,
    fontWeight: '800',
    letterSpacing: -1,
  },
  subtitle: {
    color: COLORS.muted,
    fontSize: 14,
    marginTop: 5,
  },
  aiBadge: {
    backgroundColor: '#DCFCE7',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 20,
  },
  aiBadgeText: {
    color: COLORS.darkGreen,
    fontSize: 13,
    fontWeight: '800',
  },
  heroCard: {
    padding: 24,
    borderRadius: 26,
    marginBottom: 30,
  },
  heroLabel: {
    color: '#DCFCE7',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
  heroAmount: {
    color: COLORS.white,
    fontSize: 43,
    fontWeight: '800',
    letterSpacing: -1.5,
    marginTop: 13,
  },
  heroDescription: {
    color: '#DCFCE7',
    fontSize: 13,
    lineHeight: 20,
    marginTop: 7,
  },
  heroDivider: {
    height: 1,
    backgroundColor: '#FFFFFF45',
    marginVertical: 20,
  },
  heroFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  heroFooterLabel: {
    color: '#DCFCE7',
    fontSize: 11,
  },
  heroSparkle: {
    color: COLORS.white,
    fontSize: 19,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 15,
    marginTop: 5,
  },
  sectionTitle: {
    color: COLORS.text,
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: -0.4,
  },
  sectionSubtitle: {
    color: COLORS.darkGreen,
    fontSize: 9,
    fontWeight: '800',
    letterSpacing: 1,
  },
  metricsRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 30,
  },
  metricCard: {
    flex: 1,
    overflow: 'hidden',
    borderRadius: 22,
    padding: 18,
    borderWidth: 1,
    borderColor: '#FFFFFF',
    backgroundColor: '#FFFFFFCC',
  },
  metricIcon: {
    fontSize: 21,
    marginBottom: 14,
  },
  metricValue: {
    color: COLORS.text,
    fontSize: 23,
    fontWeight: '800',
  },
  metricLabel: {
    color: COLORS.muted,
    fontSize: 11,
    marginTop: 5,
  },
  categoryCard: {
    backgroundColor: COLORS.white,
    borderRadius: 22,
    padding: 20,
    marginBottom: 30,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  categoryItem: {
    marginBottom: 21,
  },
  categoryTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  categoryName: {
    color: COLORS.text,
    fontSize: 13,
    fontWeight: '600',
  },
  categorySaving: {
    color: COLORS.darkGreen,
    fontSize: 13,
    fontWeight: '800',
  },
  progressBackground: {
    height: 7,
    backgroundColor: '#E2E8F0',
    borderRadius: 10,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.green,
    borderRadius: 10,
  },
  categoryFooter: {
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    paddingTop: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  categoryFooterLabel: {
    color: COLORS.muted,
    fontSize: 12,
  },
  categoryFooterValue: {
    color: COLORS.darkGreen,
    fontSize: 14,
    fontWeight: '800',
  },
  tipCard: {
    flexDirection: 'row',
    backgroundColor: COLORS.white,
    borderRadius: 20,
    padding: 17,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    alignItems: 'flex-start',
    gap: 14,
  },
  tipIconContainer: {
    width: 42,
    height: 42,
    borderRadius: 14,
    backgroundColor: '#DCFCE7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  tipIcon: {
    fontSize: 20,
  },
  tipContent: {
    flex: 1,
  },
  tipTitle: {
    color: COLORS.text,
    fontSize: 13,
    fontWeight: '800',
    marginBottom: 6,
  },
  tipDescription: {
    color: COLORS.muted,
    fontSize: 12,
    lineHeight: 19,
  },
  disclaimer: {
    marginTop: 12,
    paddingHorizontal: 8,
  },
  disclaimerText: {
    color: COLORS.muted,
    fontSize: 10,
    lineHeight: 16,
    textAlign: 'center',
  },
    opportunitiesCard: {
    backgroundColor: COLORS.white,
    borderRadius: 22,
    padding: 18,
    marginBottom: 30,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  opportunityItem: {
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  opportunityTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
  },
  opportunityProduct: {
    flex: 1,
  },
  opportunityName: {
    color: COLORS.text,
    fontSize: 14,
    fontWeight: '800',
  },
  opportunityBrand: {
    color: COLORS.muted,
    fontSize: 11,
    marginTop: 3,
  },
  opportunitySaving: {
    color: COLORS.darkGreen,
    fontSize: 16,
    fontWeight: '800',
  },
  opportunityDetail: {
    color: COLORS.muted,
    fontSize: 11,
    marginTop: 6,
  },
  opportunityMessage: {
    color: COLORS.muted,
    fontSize: 13,
    lineHeight: 20,
    paddingVertical: 8,
  },
  section: {
    marginBottom: 25,
  },
  emptyText: {
    color: COLORS.muted,
    fontSize: 13,
    lineHeight: 20,
    paddingVertical: 12,
  },
  movementCard: {
    backgroundColor: COLORS.white,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: 16,
    marginTop: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  movementInfo: {
    flex: 1,
    marginRight: 12,
  },
  movementProduct: {
    color: COLORS.text,
    fontSize: 14,
    fontWeight: '700',
  },
  movementRetailer: {
    color: COLORS.muted,
    fontSize: 11,
    marginTop: 3,
  },
  movementPrices: {
    color: COLORS.muted,
    fontSize: 11,
    marginTop: 7,
  },
  movementResult: {
    alignItems: 'flex-end',
  },
  movementChange: {
    fontSize: 14,
    fontWeight: '800',
  },
  movementPercentage: {
    fontSize: 11,
    fontWeight: '700',
    marginTop: 3,
  },
  movementDirection: {
    fontSize: 9,
    fontWeight: '700',
    textTransform: 'capitalize',
    marginTop: 3,
  },
    basketInsightsSection: {
    marginBottom: 25,
  },
  basketInsightsCard: {
    backgroundColor: COLORS.white,
    borderRadius: 22,
    padding: 20,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  basketSavingsLabel: {
    color: COLORS.darkGreen,
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1.3,
  },
  basketSavingsAmount: {
    color: COLORS.darkGreen,
    fontSize: 36,
    fontWeight: '900',
    marginTop: 10,
  },
  basketMessage: {
    color: COLORS.muted,
    fontSize: 12,
    lineHeight: 19,
    marginTop: 7,
  },
  basketDivider: {
    height: 1,
    backgroundColor: COLORS.border,
    marginVertical: 17,
  },
  basketRetailerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  basketRetailerInfo: {
    flex: 1,
    marginRight: 12,
  },
  basketRetailerLabel: {
    color: COLORS.muted,
    fontSize: 10,
  },
  basketRetailerName: {
    color: COLORS.text,
    fontSize: 14,
    fontWeight: '800',
    marginTop: 4,
  },
  basketRetailerPrice: {
    color: COLORS.darkGreen,
    fontSize: 15,
    fontWeight: '800',
  },
  basketComparisonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  basketComparisonName: {
    color: COLORS.text,
    fontSize: 12,
    fontWeight: '600',
  },
  basketComparisonPrice: {
    color: COLORS.text,
    fontSize: 12,
    fontWeight: '800',
  },
});