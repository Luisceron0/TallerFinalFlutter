#!/usr/bin/env python3
"""
Comprehensive API tests for GamePrice Scraper API
Run with: python test_api.py
"""

import asyncio
import aiohttp
import json
import time
from typing import Dict, Any
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class APITester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url.rstrip('/')
        self.session = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def test_health_check(self) -> Dict[str, Any]:
        """Test health check endpoint"""
        print("🩺 Testing health check...")
        try:
            async with self.session.get(f"{self.base_url}/health") as response:
                data = await response.json()
                success = response.status == 200 and data.get('status') == 'healthy'
                return {
                    'test': 'health_check',
                    'success': success,
                    'status_code': response.status,
                    'response': data
                }
        except Exception as e:
            return {
                'test': 'health_check',
                'success': False,
                'error': str(e)
            }

    async def test_search_games(self, query: str = "cyberpunk") -> Dict[str, Any]:
        """Test game search endpoint"""
        print(f"🔍 Testing game search for: {query}")
        try:
            payload = {'query': query}
            async with self.session.post(
                f"{self.base_url}/api/search",
                json=payload,
                headers={'Content-Type': 'application/json'}
            ) as response:
                data = await response.json()
                success = response.status == 200 and 'results' in data and 'search_time' in data

                if success and data['results']:
                    # Check result structure
                    result = data['results'][0]
                    has_required_fields = all(key in result for key in ['id', 'title', 'prices'])
                    ai_enabled = data.get('ai_enabled', False)
                else:
                    has_required_fields = True  # Empty results are valid
                    ai_enabled = False

                return {
                    'test': 'search_games',
                    'success': success and has_required_fields,
                    'status_code': response.status,
                    'results_count': len(data.get('results', [])),
                    'search_time': data.get('search_time'),
                    'ai_enabled': ai_enabled,
                    'response': data
                }
        except Exception as e:
            return {
                'test': 'search_games',
                'success': False,
                'error': str(e)
            }

    async def test_refresh_wishlist(self, user_id: str = "test-user", game_ids: list = None) -> Dict[str, Any]:
        """Test wishlist refresh endpoint"""
        if game_ids is None:
            game_ids = ["test-game-1", "test-game-2"]

        print(f"🔄 Testing wishlist refresh for user: {user_id}")
        try:
            payload = {
                'user_id': user_id,
                'game_ids': game_ids
            }
            async with self.session.post(
                f"{self.base_url}/api/refresh-wishlist",
                json=payload,
                headers={'Content-Type': 'application/json'}
            ) as response:
                data = await response.json()
                success = response.status == 200
                has_required_fields = all(key in data for key in ['refreshed_games', 'notifications_created', 'ai_insights_generated'])

                return {
                    'test': 'refresh_wishlist',
                    'success': success and has_required_fields,
                    'status_code': response.status,
                    'refreshed_games': data.get('refreshed_games', 0),
                    'notifications_created': data.get('notifications_created', 0),
                    'ai_insights_generated': data.get('ai_insights_generated', 0),
                    'response': data
                }
        except Exception as e:
            return {
                'test': 'refresh_wishlist',
                'success': False,
                'error': str(e)
            }

    async def test_error_handling(self) -> Dict[str, Any]:
        """Test error handling with invalid requests"""
        print("❌ Testing error handling...")

        error_tests = []

        # Test 1: Invalid search query
        try:
            async with self.session.post(
                f"{self.base_url}/api/search",
                json={'query': ''},
                headers={'Content-Type': 'application/json'}
            ) as response:
                error_tests.append({
                    'subtest': 'empty_search',
                    'success': response.status == 400 or response.status == 422,
                    'status_code': response.status
                })
        except Exception as e:
            error_tests.append({
                'subtest': 'empty_search',
                'success': False,
                'error': str(e)
            })

        # Test 2: Invalid wishlist refresh
        try:
            async with self.session.post(
                f"{self.base_url}/api/refresh-wishlist",
                json={'user_id': '', 'game_ids': []},
                headers={'Content-Type': 'application/json'}
            ) as response:
                error_tests.append({
                    'subtest': 'invalid_wishlist',
                    'success': response.status in [400, 422],
                    'status_code': response.status
                })
        except Exception as e:
            error_tests.append({
                'subtest': 'invalid_wishlist',
                'success': False,
                'error': str(e)
            })

        # Test 3: Non-existent endpoint
        try:
            async with self.session.get(f"{self.base_url}/nonexistent") as response:
                error_tests.append({
                    'subtest': 'nonexistent_endpoint',
                    'success': response.status == 404,
                    'status_code': response.status
                })
        except Exception as e:
            error_tests.append({
                'subtest': 'nonexistent_endpoint',
                'success': False,
                'error': str(e)
            })

        all_passed = all(test['success'] for test in error_tests)
        return {
            'test': 'error_handling',
            'success': all_passed,
            'subtests': error_tests
        }

    async def run_all_tests(self) -> Dict[str, Any]:
        """Run all API tests"""
        print("🚀 Starting comprehensive API tests...\n")

        results = []

        # Test health check
        health_result = await self.test_health_check()
        results.append(health_result)
        print(f"Health Check: {'✅ PASS' if health_result['success'] else '❌ FAIL'}")

        # Test search functionality
        search_result = await self.test_search_games()
        results.append(search_result)
        print(f"Game Search: {'✅ PASS' if search_result['success'] else '❌ FAIL'}")

        # Test wishlist refresh
        wishlist_result = await self.test_refresh_wishlist()
        results.append(wishlist_result)
        print(f"Wishlist Refresh: {'✅ PASS' if wishlist_result['success'] else '❌ FAIL'}")

        # Test error handling
        error_result = await self.test_error_handling()
        results.append(error_result)
        print(f"Error Handling: {'✅ PASS' if error_result['success'] else '❌ FAIL'}")

        # Calculate overall results
        passed_tests = sum(1 for r in results if r['success'])
        total_tests = len(results)

        print(f"\n📊 Test Results: {passed_tests}/{total_tests} tests passed")

        # Performance check
        if search_result['success'] and 'search_time' in search_result:
            search_time = search_result['search_time']
            print(f"⚡ Search Performance: {search_time:.2f}s {'(Good)' if search_time < 5.0 else '(Slow)'}")

        return {
            'summary': {
                'total_tests': total_tests,
                'passed_tests': passed_tests,
                'success_rate': f"{(passed_tests/total_tests)*100:.1f}%"
            },
            'results': results,
            'timestamp': time.time()
        }


async def main():
    """Main test runner"""
    # Use environment variable for base URL or default to localhost
    base_url = os.getenv('API_BASE_URL', 'http://localhost:8000')

    print(f"🎯 Testing API at: {base_url}")

    async with APITester(base_url) as tester:
        results = await tester.run_all_tests()

        # Save results to file
        with open('api_test_results.json', 'w') as f:
            json.dump(results, f, indent=2)

        print("💾 Results saved to api_test_results.json")

        # Exit with appropriate code
        if results['summary']['passed_tests'] == results['summary']['total_tests']:
            print("🎉 All tests passed!")
            return 0
        else:
            print("⚠️  Some tests failed. Check api_test_results.json for details.")
            return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
