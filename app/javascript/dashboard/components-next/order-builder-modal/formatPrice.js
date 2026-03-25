/**
 * Format a price with Intl.NumberFormat.
 * Shared across ReviewStep, OrderBuilderModal, and CartSidebar.
 */
export function formatPrice(price, currency = 'THB') {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${currency} ${price}`;
  }
}
