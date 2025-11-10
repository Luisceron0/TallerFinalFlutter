# Purchase Decision Assistant Implementation

## Backend Changes
- [ ] Add `analyze_purchase_decision` method to GeminiService with structured JSON response
- [ ] Create new `/api/analyze-purchase` endpoint in FastAPI
- [ ] Implement price history retrieval and user profile analysis
- [ ] Add caching mechanism for AI responses

## Frontend Changes
- [ ] Add "🤖 ¿Debería comprarlo?" button to GameDetailPage
- [ ] Create modal/dialog for displaying detailed purchase analysis
- [ ] Update ScraperApiService with new purchase analysis method
- [ ] Handle loading states and error cases

## Data Model Updates
- [ ] Potentially extend GameEntity or create new model for detailed analysis
- [ ] Ensure proper JSON structure for AI responses

## Additional Tasks
- [ ] Remove notifications tab from the app
- [ ] Verify games are properly added to wishlist

## Followup Steps
- [ ] Test the new endpoint with sample data
- [ ] Implement caching to avoid repeated API calls
- [ ] Add error handling for AI service failures
- [ ] Update UI to handle different analysis scenarios
