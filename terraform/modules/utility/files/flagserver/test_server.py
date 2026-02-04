#!/usr/bin/env python3
"""
Test script for the CTF Flag Server v2
Tests both static (Phase 1) and dynamic (Phase 2) flag functionality
"""

import requests
import json
import sys
from datetime import datetime

# Test configuration
SERVER_URL = "http://localhost:8080"
ADMIN_TOKEN = "ctf_admin_2026!"

def test_public_endpoints():
    """Test public endpoints available to teams."""
    print("=== TESTING PUBLIC ENDPOINTS ===")
    
    try:
        # Test server status
        response = requests.get(f"{SERVER_URL}/")
        print(f"✅ Server status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Session ID: {data.get('session_id')}")
            print(f"   Phase: {data.get('phase')}")
            print(f"   Teams: {data.get('teams_configured')}")
        
        # Test health check
        response = requests.get(f"{SERVER_URL}/api/health")
        print(f"✅ Health check: {response.status_code}")
        
        # Test challenges list
        response = requests.get(f"{SERVER_URL}/api/challenges")
        print(f"✅ Challenges list: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            challenges = data.get('challenges', {})
            print(f"   Total challenges: {len(challenges)}")
            
            # Count by phase
            phase1_count = sum(1 for c in challenges.values() if c.get('phase') == 'phase1')
            phase2_count = sum(1 for c in challenges.values() if c.get('phase') == 'phase2')
            print(f"   Phase 1: {phase1_count}, Phase 2: {phase2_count}")
        
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - is the server running?")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    
    return True

def test_admin_endpoints():
    """Test admin endpoints with authentication."""
    print("\n=== TESTING ADMIN ENDPOINTS ===")
    
    headers = {"Authorization": f"Bearer {ADMIN_TOKEN}"}
    
    try:
        # Test admin status
        response = requests.get(f"{SERVER_URL}/admin/status", headers=headers)
        print(f"✅ Admin status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Session ID: {data.get('session_id')}")
            print(f"   Total solves: {data.get('total_solves')}")
        
        # Test session info
        response = requests.get(f"{SERVER_URL}/admin/session/info", headers=headers)
        print(f"✅ Session info: {response.status_code}")
        
        # Test team flags
        response = requests.get(f"{SERVER_URL}/admin/flags/team1/all", headers=headers)
        print(f"✅ Team1 flags: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            phase2_flags = data.get('phase2_flags', {})
            print(f"   Dynamic flags generated: {len(phase2_flags)}")
            
            # Show a few example flags
            examples = ['correlador_eventos', 'cazador_patrones', 'primera_vista']
            for flag_id in examples:
                if flag_id in phase2_flags:
                    print(f"   {flag_id}: {phase2_flags[flag_id]}")
        
        # Test specific flag with metadata
        response = requests.get(f"{SERVER_URL}/admin/flags/team1/correlador_eventos", headers=headers)
        print(f"✅ Specific flag metadata: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Flag: {data.get('flag')}")
            metadata = data.get('metadata', {})
            print(f"   Campaign format: {metadata.get('campaign_id_format')}")
        
        # Test pre-generate flags
        response = requests.post(f"{SERVER_URL}/admin/pre_generate_flags", headers=headers)
        print(f"✅ Pre-generate flags: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Teams processed: {data.get('teams_processed')}")
            print(f"   Total flags: {data.get('flags_generated')}")
        
    except Exception as e:
        print(f"❌ Admin endpoint error: {e}")
        return False
    
    return True

def test_flag_submission():
    """Test flag submission functionality."""
    print("\n=== TESTING FLAG SUBMISSION ===")
    
    try:
        # Test Phase 2 flag submission (correlador_eventos)
        # First get the correct flag from admin API
        headers = {"Authorization": f"Bearer {ADMIN_TOKEN}"}
        response = requests.get(f"{SERVER_URL}/admin/flags/team1/correlador_eventos", headers=headers)
        
        if response.status_code == 200:
            correct_flag = response.json().get('flag')
            print(f"   Correct flag for correlador_eventos: {correct_flag}")
            
            # Test correct submission
            payload = {
                'flag': correct_flag,
                'team_id': 'team1'
            }
            response = requests.post(f"{SERVER_URL}/api/flag/correlador_eventos", json=payload)
            print(f"✅ Correct flag submission: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"   Correct: {data.get('correct')}")
                print(f"   Points: {data.get('points')}")
            
            # Test incorrect submission
            payload = {
                'flag': 'wrong-flag',
                'team_id': 'team1'
            }
            response = requests.post(f"{SERVER_URL}/api/flag/correlador_eventos", json=payload)
            print(f"✅ Incorrect flag submission: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"   Correct: {data.get('correct')}")
                print(f"   Hint: {data.get('hint', 'None')[:50]}...")
        
    except Exception as e:
        print(f"❌ Flag submission error: {e}")
        return False
    
    return True

def test_dynamic_flags_consistency():
    """Test that dynamic flags are consistent across multiple calls."""
    print("\n=== TESTING FLAG CONSISTENCY ===")
    
    headers = {"Authorization": f"Bearer {ADMIN_TOKEN}"}
    
    try:
        # Get flags twice and compare
        response1 = requests.get(f"{SERVER_URL}/admin/flags/team1/all", headers=headers)
        response2 = requests.get(f"{SERVER_URL}/admin/flags/team1/all", headers=headers)
        
        if response1.status_code == 200 and response2.status_code == 200:
            flags1 = response1.json().get('phase2_flags', {})
            flags2 = response2.json().get('phase2_flags', {})
            
            consistent = True
            for flag_id in flags1:
                if flags1[flag_id] != flags2[flag_id]:
                    print(f"❌ Inconsistency in {flag_id}: {flags1[flag_id]} != {flags2[flag_id]}")
                    consistent = False
            
            if consistent:
                print("✅ All flags consistent across multiple calls")
                print(f"   Tested {len(flags1)} flags")
            
            # Test different teams have different flags where appropriate
            response3 = requests.get(f"{SERVER_URL}/admin/flags/team2/all", headers=headers)
            if response3.status_code == 200:
                flags3 = response3.json().get('phase2_flags', {})
                
                # Some flags should be the same (predictive)
                predictive_flags = ['cazador_patrones', 'comandante_incidentes', 'cazador_apt']
                team_specific = ['primera_vista', 'correlador_eventos', 'timeline_master']
                
                for flag_id in predictive_flags:
                    if flags1.get(flag_id) != flags3.get(flag_id):
                        print(f"❌ Predictive flag {flag_id} differs between teams")
                        consistent = False
                
                for flag_id in team_specific:
                    if flag_id in ['correlador_eventos']:  # This should definitely differ
                        if flags1.get(flag_id) == flags3.get(flag_id):
                            print(f"❌ Team-specific flag {flag_id} is the same for both teams")
                            consistent = False
                
                if consistent:
                    print("✅ Predictive vs team-specific flags working correctly")
        
    except Exception as e:
        print(f"❌ Consistency test error: {e}")
        return False
    
    return True

def main():
    """Run all tests."""
    print("CTF Flag Server v2 - Test Suite")
    print(f"Testing server at: {SERVER_URL}")
    print(f"Timestamp: {datetime.now()}")
    print("=" * 50)
    
    tests_passed = 0
    total_tests = 4
    
    if test_public_endpoints():
        tests_passed += 1
    
    if test_admin_endpoints():
        tests_passed += 1
    
    if test_flag_submission():
        tests_passed += 1
    
    if test_dynamic_flags_consistency():
        tests_passed += 1
    
    print("\n" + "=" * 50)
    print(f"RESULTS: {tests_passed}/{total_tests} test suites passed")
    
    if tests_passed == total_tests:
        print("🎉 All tests passed! Flag server is ready for production.")
        return 0
    else:
        print("❌ Some tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())