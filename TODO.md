# Flutter App Corrections - 5 Pending Fixes

## 1. Fix Authentication Flow
- [ ] Verify AuthGate session checking logic
- [ ] Ensure proper redirect to AuthPage when not logged in
- [ ] Test login/logout functionality

## 2. Update Wishlist Price Display
- [ ] Verify _buildPriceInfo method shows current prices from price_history
- [ ] Ensure both Steam and Epic prices are displayed correctly
- [ ] Handle cases where prices are not available

## 3. Enhance Game Detail Prices
- [ ] Modify _buildPriceComparison to show both Steam and Epic prices
- [ ] Add indication when game is only available in one store
- [ ] Improve price display formatting and layout

## 4. Verify Wishlist Navigation
- [ ] Confirm onTap handlers navigate to game detail page
- [ ] Test navigation from wishlist items to GameDetailPage
- [ ] Ensure proper game data is passed in navigation

## 5. Confirm Gemini AI Fix
- [ ] Verify fallback from gemini-1.5-flash to gemini-pro is working
- [ ] Test AI service error handling
- [ ] Confirm no more 404 errors for models/gemini-1.5-flash

## Followup Steps
- [ ] Test all fixes end-to-end
- [ ] Update this TODO with completion status
- [ ] Verify no regressions in existing functionality
