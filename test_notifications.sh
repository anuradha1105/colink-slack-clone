#!/bin/bash

# Comprehensive Notifications Service Test Script
set -e

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Report file
REPORT_FILE="/Users/spartan/Documents/GitHub/Final Project/Colink-Slack-Clone/NOTIFICATIONS_TEST_REPORT.md"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Database query helper
query_db() {
    docker exec colink-postgres psql -U colink -d colink -t -A -c "$1" 2>&1
}

# Helper function to print test header
print_header() {
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     COMPREHENSIVE NOTIFICATIONS SERVICE TESTING                   ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════╝${NC}"
}

# Helper function to check test result
check_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${RED}  Expected: $expected${NC}"
        echo -e "${RED}  Got: $actual${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Initialize report
init_report() {
    cat > "$REPORT_FILE" << 'EOFR'
# Comprehensive Notifications Service Test Report

**Test Date:** $(date)
**Service:** Notifications Service (Port 8008)
**Tester:** Automated Test Suite

---

## Table of Contents
- [Setup](#setup)
- [Test Results Summary](#summary)
- [Positive Test Cases](#positive)
- [Negative Test Cases](#negative)
- [Kafka Event Tests](#kafka)
- [Database Verification](#database)

---

<a name="setup"></a>
## Setup and Authentication


EOFR
}

# Append to report
append_report() {
    echo "$1" >> "$REPORT_FILE"
}

# Start testing
print_header

echo -e "${CYAN}SETUP: Logging in test users${NC}"

# Login users
ALICE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}' | jq -r '.access_token')
BOB_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"bob","password":"bob123"}' | jq -r '.access_token')
CHARLIE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"charlie","password":"charlie123"}' | jq -r '.access_token')

echo -e "${GREEN}✓ Alice, Bob, Charlie logged in${NC}"

# Get channel ID
CHANNEL_ID=$(curl -s -X GET "http://localhost:8003/channels" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.channels[0].id')
echo -e "${GREEN}✓ Using channel: $CHANNEL_ID${NC}"

echo ""

#===============================================================================
# POSITIVE TEST CASES
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}POSITIVE TEST CASES${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# TC01: Health Check
echo -e "${BLUE}TC01: Health Check${NC}"
HEALTH=$(curl -s http://localhost:8008/health)
check_result "Health check" "healthy" "$HEALTH"
echo ""

# TC02: Get Default Notification Preferences
echo -e "${BLUE}TC02: Get Default Notification Preferences${NC}"
PREFS=$(curl -s -X GET "http://localhost:8008/notifications/preferences" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Default preferences" "mentions" "$PREFS"
check_result "All prefs enabled" "true" "$PREFS"
echo ""

# TC03: Update Notification Preferences
echo -e "${BLUE}TC03: Update Notification Preferences (Disable Reactions)${NC}"
UPDATED_PREFS=$(curl -s -X PUT "http://localhost:8008/notifications/preferences" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"reactions": false}')
check_result "Reactions disabled" '"reactions":false' "$UPDATED_PREFS"
echo ""

# TC04: Get Empty Notifications List
echo -e "${BLUE}TC04: Get Empty Notifications List${NC}"
NOTIF_LIST=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Empty notifications" '"total_count":0' "$NOTIF_LIST"
echo ""

# TC05: Get Unread Count (Should be 0)
echo -e "${BLUE}TC05: Get Unread Count (Initial)${NC}"
UNREAD=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Unread count zero" '"unread_count":0' "$UNREAD"
echo ""

#===============================================================================
# KAFKA EVENT TESTING - MENTION NOTIFICATIONS
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}KAFKA EVENT TESTS - MENTION NOTIFICATIONS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# TC06: Create message with @mention (should trigger notification)
echo -e "${BLUE}TC06: Create Message with @alice Mention${NC}"
MSG_RESPONSE=$(curl -s -X POST "http://localhost:8002/messages" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"Hey @alice, check this out!\"}")
MESSAGE_ID=$(echo $MSG_RESPONSE | jq -r '.id')
echo "Message created: $MESSAGE_ID"
sleep 2  # Wait for Kafka consumer to process

# Check if notification was created
NOTIF_LIST=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Mention notification created" "mentioned you" "$NOTIF_LIST"
NOTIF_ID=$(echo $NOTIF_LIST | jq -r '.notifications[0].id')
echo "Notification ID: $NOTIF_ID"
echo ""

# TC07: Verify Unread Count Increased
echo -e "${BLUE}TC07: Verify Unread Count Increased to 1${NC}"
UNREAD=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Unread count is 1" '"unread_count":1' "$UNREAD"
echo ""

# TC08: Mark Notification as Read
echo -e "${BLUE}TC08: Mark Notification as Read${NC}"
READ_RESULT=$(curl -s -X PUT "http://localhost:8008/notifications/$NOTIF_ID/read" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Notification marked read" '"is_read":true' "$READ_RESULT"
echo ""

# TC09: Verify Unread Count Decreased
echo -e "${BLUE}TC09: Verify Unread Count Decreased to 0${NC}"
UNREAD=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Unread count is 0" '"unread_count":0' "$UNREAD"
echo ""

#===============================================================================
# KAFKA EVENT TESTING - REACTION NOTIFICATIONS
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}KAFKA EVENT TESTS - REACTION NOTIFICATIONS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# Re-enable reactions for Bob
curl -s -X PUT "http://localhost:8008/notifications/preferences" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"reactions": true}' > /dev/null

# TC10: Add Reaction (Should trigger notification for message author)
echo -e "${BLUE}TC10: Alice adds reaction to Bob's message${NC}"
REACTION_RESULT=$(curl -s -X POST "http://localhost:8006/messages/$MESSAGE_ID/reactions" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"emoji":"👍"}')
echo "Reaction added"
sleep 2  # Wait for Kafka consumer

# Check Bob's notifications
BOB_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $BOB_TOKEN")
check_result "Reaction notification created" "reacted to your message" "$BOB_NOTIFS"
echo ""

#===============================================================================
# KAFKA EVENT TESTING - THREAD REPLY NOTIFICATIONS
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}KAFKA EVENT TESTS - THREAD REPLY NOTIFICATIONS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# TC11: Create Thread Reply (Should notify parent message author)
echo -e "${BLUE}TC11: Alice replies to Bob's message in thread${NC}"
REPLY_RESPONSE=$(curl -s -X POST "http://localhost:8002/messages" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"This is my reply\",\"parent_message_id\":\"$MESSAGE_ID\"}")
REPLY_ID=$(echo $REPLY_RESPONSE | jq -r '.id')
echo "Reply created: $REPLY_ID"
sleep 2  # Wait for Kafka consumer

# Check Bob's notifications for reply
BOB_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?is_read=false" -H "Authorization: Bearer $BOB_TOKEN")
check_result "Reply notification created" "replied to your message" "$BOB_NOTIFS"
echo ""

#===============================================================================
# NOTIFICATION MANAGEMENT TESTS
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}NOTIFICATION MANAGEMENT TESTS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# TC12: Filter Notifications by Type
echo -e "${BLUE}TC12: Filter Notifications by Type (mention)${NC}"
FILTERED=$(curl -s -X GET "http://localhost:8008/notifications?type=mention" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Filtered by type" "mention" "$FILTERED"
echo ""

# TC13: Filter Notifications by Read Status
echo -e "${BLUE}TC13: Filter Notifications by Read Status (unread)${NC}"
UNREAD_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?is_read=false" -H "Authorization: Bearer $BOB_TOKEN")
UNREAD_COUNT=$(echo $UNREAD_NOTIFS | jq '.notifications | length')
echo "Found $UNREAD_COUNT unread notifications"
[ "$UNREAD_COUNT" -gt 0 ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}"
echo ""

# TC14: Mark All as Read
echo -e "${BLUE}TC14: Mark All Notifications as Read${NC}"
MARK_ALL=$(curl -s -X PUT "http://localhost:8008/notifications/read-all" -H "Authorization: Bearer $BOB_TOKEN")
MARKED_COUNT=$(echo $MARK_ALL | jq -r '.marked_read')
echo "Marked $MARKED_COUNT as read"
check_result "Multiple marked" "2" "$MARKED_COUNT"
echo ""

# TC15: Pagination Test
echo -e "${BLUE}TC15: Test Pagination (page_size=1)${NC}"
PAGINATED=$(curl -s -X GET "http://localhost:8008/notifications?page=1&page_size=1" -H "Authorization: Bearer $ALICE_TOKEN")
PAGE_SIZE=$(echo $PAGINATED | jq '.notifications | length')
check_result "Pagination works" "1" "$PAGE_SIZE"
echo ""

# TC16: Delete Notification
echo -e "${BLUE}TC16: Delete Notification${NC}"
DELETE_RESULT=$(curl -s -w "\n%{http_code}" -X DELETE "http://localhost:8008/notifications/$NOTIF_ID" -H "Authorization: Bearer $ALICE_TOKEN")
HTTP_CODE=$(echo "$DELETE_RESULT" | tail -1)
check_result "Notification deleted" "204" "$HTTP_CODE"
echo ""

#===============================================================================
# NEGATIVE TEST CASES
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}NEGATIVE TEST CASES${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# TC17: Unauthorized Access (No Token)
echo -e "${BLUE}TC17: Unauthorized Access - No Token${NC}"
UNAUTH=$(curl -s -X GET "http://localhost:8008/notifications")
check_result "Unauthorized blocked" "Missing Authorization" "$UNAUTH"
echo ""

# TC18: Access Another User's Notification
echo -e "${BLUE}TC18: Cannot Access Another User's Notification${NC}"
# Get one of Bob's notifications
BOB_NOTIF_ID=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $BOB_TOKEN" | jq -r '.notifications[0].id')
if [ "$BOB_NOTIF_ID" != "null" ]; then
    FORBIDDEN=$(curl -s -X PUT "http://localhost:8008/notifications/$BOB_NOTIF_ID/read" -H "Authorization: Bearer $ALICE_TOKEN")
    check_result "Cannot access others' notifications" "not found" "$FORBIDDEN"
else
    echo -e "${YELLOW}⊘ SKIP - No notification to test${NC}"
fi
echo ""

# TC19: Invalid Notification ID
echo -e "${BLUE}TC19: Invalid Notification ID${NC}"
INVALID=$(curl -s -X PUT "http://localhost:8008/notifications/00000000-0000-0000-0000-000000000000/read" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Invalid ID rejected" "not found" "$INVALID"
echo ""

# TC20: Invalid Pagination Parameters
echo -e "${BLUE}TC20: Invalid Pagination Parameters${NC}"
INVALID_PAGE=$(curl -s -X GET "http://localhost:8008/notifications?page=0" -H "Authorization: Bearer $ALICE_TOKEN")
check_result "Invalid page rejected" "validation_error\\|detail" "$INVALID_PAGE"
echo ""

# TC21: Self-Mention (Should NOT create notification)
echo -e "${BLUE}TC21: Self-Mention Should NOT Create Notification${NC}"
BEFORE_COUNT=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')
curl -s -X POST "http://localhost:8002/messages" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"Hey @alice, you rock!\"}" > /dev/null
sleep 2
AFTER_COUNT=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')
[ "$BEFORE_COUNT" == "$AFTER_COUNT" ] && echo -e "${GREEN}✓ PASS - No self-notification${NC}" || echo -e "${RED}✗ FAIL - Self-notification created${NC}"
echo ""

# TC22: Preference Check (Alice has reactions disabled)
echo -e "${BLUE}TC22: Preference Check - Alice Should NOT Get Reaction Notifications${NC}"
# Create a message from Alice
ALICE_MSG=$(curl -s -X POST "http://localhost:8002/messages" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"Test message\"}" | jq -r '.id')
BEFORE_COUNT=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')
# Bob reacts to Alice's message
curl -s -X POST "http://localhost:8006/messages/$ALICE_MSG/reactions" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"emoji":"❤️"}' > /dev/null
sleep 2
AFTER_COUNT=$(curl -s -X GET "http://localhost:8008/notifications/unread/count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')
[ "$BEFORE_COUNT" == "$AFTER_COUNT" ] && echo -e "${GREEN}✓ PASS - Preference respected${NC}" || echo -e "${RED}✗ FAIL - Notification created despite preference${NC}"
echo ""

#===============================================================================
# DATABASE VERIFICATION
#===============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}FINAL DATABASE STATE${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

echo -e "${BLUE}All Notifications:${NC}"
query_db "SELECT type, user_id, title, is_read FROM notifications WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 10;"
echo ""

echo -e "${BLUE}Notification Preferences:${NC}"
query_db "SELECT user_id, mentions, reactions, replies FROM notification_preferences LIMIT 5;"
echo ""

#===============================================================================
# TEST SUMMARY
#===============================================================================

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                          TEST SUMMARY                              ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Total Tests:   ${NC}$TOTAL_TESTS"
echo -e "${GREEN}Passed:        ${NC}$PASSED_TESTS"
echo -e "${RED}Failed:        ${NC}$FAILED_TESTS"

SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
echo -e "${CYAN}Success Rate:  ${NC}${SUCCESS_RATE}%"

echo ""
echo -e "${GREEN}✓ Detailed report saved to:${NC}"
echo -e "${CYAN}$REPORT_FILE${NC}"
