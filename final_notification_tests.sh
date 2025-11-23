#!/bin/bash

# Comprehensive Notification Service Tests
# Tests all notification APIs with proper validation

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test tracking
declare -a FAILED_TEST_NAMES

print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_test() {
    echo -e "${BLUE}TEST: $1${NC}"
}

print_pass() {
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    echo -e "${GREEN}✓ PASS: $1${NC}"
}

print_fail() {
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    FAILED_TEST_NAMES+=("$1")
    echo -e "${RED}✗ FAIL: $1${NC}"
    if [ -n "$2" ]; then
        echo -e "${RED}  Details: $2${NC}"
    fi
}

wait_for_kafka() {
    echo -e "${YELLOW}⏳ Waiting $1s for Kafka event processing...${NC}"
    sleep $1
}

# Initialize test environment
print_header "INITIALIZING TEST ENVIRONMENT"

echo "Logging in test users..."
ALICE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}' | jq -r '.access_token')
BOB_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"bob","password":"bob123"}' | jq -r '.access_token')
CHARLIE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"charlie","password":"charlie123"}' | jq -r '.access_token')

if [ "$ALICE_TOKEN" = "null" ] || [ "$BOB_TOKEN" = "null" ] || [ "$CHARLIE_TOKEN" = "null" ]; then
    echo -e "${RED}✗ Failed to login test users${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Test users logged in${NC}"

# Get channel
CHANNEL_ID=$(curl -s -X GET "http://localhost:8003/channels" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.channels[0].id')
echo -e "${GREEN}✓ Using channel: $CHANNEL_ID${NC}"

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 1: MENTION NOTIFICATIONS
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 1: MENTION NOTIFICATIONS"

# Clear Alice's notifications
curl -s -X DELETE "http://localhost:8008/notifications/all" -H "Authorization: Bearer $ALICE_TOKEN" > /dev/null

# Test 1.1: Single mention
print_test "1.1: Bob mentions @alice in message"
MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"Hey @alice, check this out!\", \"type\": \"text\"}")
MESSAGE_ID=$(echo $MSG_RESPONSE | jq -r '.id')

if [ "$MESSAGE_ID" != "null" ]; then
    print_pass "Message created: $MESSAGE_ID"
else
    print_fail "Failed to create message"
fi

wait_for_kafka 6

NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?notification_type=mention" -H "Authorization: Bearer $ALICE_TOKEN")
MENTION_COUNT=$(echo $NOTIFS | jq '.notifications | length')

if [ "$MENTION_COUNT" -gt "0" ]; then
    print_pass "Alice received $MENTION_COUNT mention notification(s)"
else
    print_fail "Alice received no mention notifications" "Expected at least 1"
fi

# Test 1.2: Multiple mentions in one message
print_test "1.2: Alice mentions both @bob and @charlie"
MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"@bob and @charlie please review\", \"type\": \"text\"}")

wait_for_kafka 6

BOB_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?notification_type=mention" -H "Authorization: Bearer $BOB_TOKEN")
BOB_COUNT=$(echo $BOB_NOTIFS | jq '.notifications | length')

CHARLIE_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?notification_type=mention" -H "Authorization: Bearer $CHARLIE_TOKEN")
CHARLIE_COUNT=$(echo $CHARLIE_NOTIFS | jq '.notifications | length')

if [ "$BOB_COUNT" -gt "0" ] && [ "$CHARLIE_COUNT" -gt "0" ]; then
    print_pass "Both Bob and Charlie received mentions"
else
    print_fail "Broadcast mention failed" "Bob: $BOB_COUNT, Charlie: $CHARLIE_COUNT"
fi

# Test 1.3: Self-mention should not create notification
print_test "1.3: Self-mention should not create notification"
BEFORE_COUNT=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN" | jq '.total_count')

MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"Note to @alice self\", \"type\": \"text\"}")

wait_for_kafka 6

AFTER_COUNT=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN" | jq '.total_count')

if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
    print_pass "Self-mention correctly ignored"
else
    print_fail "Self-mention created notification" "Before: $BEFORE_COUNT, After: $AFTER_COUNT"
fi

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 2: NOTIFICATION PREFERENCES
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 2: NOTIFICATION PREFERENCES"

# Test 2.1: Get preferences
print_test "2.1: Get user preferences"
PREFS=$(curl -s -X GET "http://localhost:8008/notifications/preferences" -H "Authorization: Bearer $ALICE_TOKEN")
MENTIONS_ENABLED=$(echo $PREFS | jq -r '.mentions')

if [ "$MENTIONS_ENABLED" != "null" ]; then
    print_pass "Preferences retrieved successfully"
else
    print_fail "Failed to get preferences"
fi

# Test 2.2: Update preferences
print_test "2.2: Disable mention notifications"
UPDATE_RESULT=$(curl -s -X PUT "http://localhost:8008/notifications/preferences" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"mentions": false}')

NEW_MENTIONS=$(echo $UPDATE_RESULT | jq -r '.mentions')

if [ "$NEW_MENTIONS" = "false" ]; then
    print_pass "Preferences updated successfully"
else
    print_fail "Failed to update preferences"
fi

# Test 2.3: Verify filtering works
print_test "2.3: Mention notification correctly filtered"
BEFORE_COUNT=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN" | jq '.total_count')

MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"Hey @alice filtered mention\", \"type\": \"text\"}")

wait_for_kafka 6

AFTER_COUNT=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN" | jq '.total_count')

if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
    print_pass "Notification correctly filtered"
else
    print_fail "Filter did not work" "Before: $BEFORE_COUNT, After: $AFTER_COUNT"
fi

# Re-enable for other tests
curl -s -X PUT "http://localhost:8008/notifications/preferences" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"mentions": true}' > /dev/null

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 3: MARK AS READ/UNREAD
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 3: MARK AS READ/UNREAD"

# Create a fresh notification
MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"@alice test read status\", \"type\": \"text\"}")
wait_for_kafka 6

# Test 3.1: Mark single notification as read
print_test "3.1: Mark single notification as read"
NOTIF_DATA=$(curl -s -X GET "http://localhost:8008/notifications?is_read=false&page_size=1" -H "Authorization: Bearer $ALICE_TOKEN")
UNREAD_BEFORE=$(echo $NOTIF_DATA | jq -r '.unread_count')
NOTIF_ID=$(echo $NOTIF_DATA | jq -r '.notifications[0].id')

if [ "$NOTIF_ID" != "null" ]; then
    MARK_RESULT=$(curl -s -X PUT "http://localhost:8008/notifications/$NOTIF_ID/read" -H "Authorization: Bearer $ALICE_TOKEN")
    IS_READ=$(echo $MARK_RESULT | jq -r '.is_read')

    NOTIF_DATA_AFTER=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN")
    UNREAD_AFTER=$(echo $NOTIF_DATA_AFTER | jq -r '.unread_count')

    if [ "$IS_READ" = "true" ] && [ "$UNREAD_AFTER" -lt "$UNREAD_BEFORE" ]; then
        print_pass "Notification marked as read (unread: $UNREAD_BEFORE → $UNREAD_AFTER)"
    else
        print_fail "Mark as read failed" "is_read=$IS_READ, unread: $UNREAD_BEFORE → $UNREAD_AFTER"
    fi
else
    print_fail "No unread notification to test"
fi

# Test 3.2: Mark all as read
print_test "3.2: Mark all notifications as read"
UNREAD_BEFORE=$(curl -s -X GET "http://localhost:8008/notifications/unread-count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')

if [ "$UNREAD_BEFORE" -gt "0" ]; then
    MARK_ALL_RESULT=$(curl -s -X PUT "http://localhost:8008/notifications/read-all" -H "Authorization: Bearer $ALICE_TOKEN")
    MARKED_COUNT=$(echo $MARK_ALL_RESULT | jq -r '.marked_read')

    UNREAD_AFTER=$(curl -s -X GET "http://localhost:8008/notifications/unread-count" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.unread_count')

    if [ "$UNREAD_AFTER" -eq "0" ]; then
        print_pass "All notifications marked as read ($MARKED_COUNT notifications)"
    else
        print_fail "Mark all as read failed" "Still have $UNREAD_AFTER unread"
    fi
else
    echo -e "${YELLOW}  SKIP: No unread notifications to test${NC}"
fi

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 4: PAGINATION AND FILTERING
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 4: PAGINATION AND FILTERING"

# Generate multiple notifications
echo "Generating test notifications..."
for i in {1..5}; do
    curl -s -X POST http://localhost:8002/messages \
        -H "Authorization: Bearer $BOB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"@alice pagination test $i\", \"type\": \"text\"}" > /dev/null
done
wait_for_kafka 8

# Test 4.1: Pagination
print_test "4.1: Pagination with page_size=3"
PAGE1=$(curl -s -X GET "http://localhost:8008/notifications?page=1&page_size=3" -H "Authorization: Bearer $ALICE_TOKEN")
PAGE1_COUNT=$(echo $PAGE1 | jq '.notifications | length')
TOTAL_COUNT=$(echo $PAGE1 | jq '.total_count')

if [ "$PAGE1_COUNT" -le "3" ] && [ "$TOTAL_COUNT" -gt "0" ]; then
    print_pass "Pagination working (returned $PAGE1_COUNT items, total: $TOTAL_COUNT)"
else
    print_fail "Pagination failed" "Returned $PAGE1_COUNT items"
fi

# Test 4.2: Filter by type
print_test "4.2: Filter by notification type (mentions)"
FILTERED=$(curl -s -X GET "http://localhost:8008/notifications?notification_type=mention" -H "Authorization: Bearer $ALICE_TOKEN")
FILTERED_NOTIFS=$(echo $FILTERED | jq '.notifications')
ALL_MENTIONS=$(echo $FILTERED_NOTIFS | jq 'all(.[]; .type == "mention")')

if [ "$ALL_MENTIONS" = "true" ]; then
    print_pass "Type filtering working correctly"
else
    print_fail "Type filtering returned non-mention notifications"
fi

# Test 4.3: Filter by read status
print_test "4.3: Filter by read status"
READ_NOTIFS=$(curl -s -X GET "http://localhost:8008/notifications?is_read=true" -H "Authorization: Bearer $ALICE_TOKEN")
ALL_READ=$(echo $READ_NOTIFS | jq '.notifications | all(.[]; .is_read == true)')

if [ "$ALL_READ" = "true" ] || [ "$(echo $READ_NOTIFS | jq '.notifications | length')" -eq "0" ]; then
    print_pass "Read status filtering working"
else
    print_fail "Read status filter returned unread notifications"
fi

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 5: NOTIFICATION DELETION
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 5: NOTIFICATION DELETION"

# Test 5.1: Delete single notification
print_test "5.1: Delete single notification"
NOTIF_DATA=$(curl -s -X GET "http://localhost:8008/notifications?page_size=1" -H "Authorization: Bearer $ALICE_TOKEN")
TOTAL_BEFORE=$(echo $NOTIF_DATA | jq '.total_count')
DELETE_ID=$(echo $NOTIF_DATA | jq -r '.notifications[0].id')

if [ "$DELETE_ID" != "null" ]; then
    DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "http://localhost:8008/notifications/$DELETE_ID" -H "Authorization: Bearer $ALICE_TOKEN")
    STATUS_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)

    TOTAL_AFTER=$(curl -s -X GET "http://localhost:8008/notifications" -H "Authorization: Bearer $ALICE_TOKEN" | jq '.total_count')

    if [ "$STATUS_CODE" = "204" ] && [ "$TOTAL_AFTER" -lt "$TOTAL_BEFORE" ]; then
        print_pass "Notification deleted successfully"
    else
        print_fail "Delete failed" "Status: $STATUS_CODE, Total: $TOTAL_BEFORE → $TOTAL_AFTER"
    fi
else
    echo -e "${YELLOW}  SKIP: No notifications to delete${NC}"
fi

#═══════════════════════════════════════════════════════════════════════════
# TEST SUITE 6: UNREAD COUNT
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUITE 6: UNREAD COUNT"

# Test 6.1: Unread count endpoint
print_test "6.1: Get unread count"
UNREAD_RESPONSE=$(curl -s -X GET "http://localhost:8008/notifications/unread-count" -H "Authorization: Bearer $ALICE_TOKEN")
UNREAD_COUNT=$(echo $UNREAD_RESPONSE | jq -r '.unread_count')

if [ "$UNREAD_COUNT" != "null" ] && [ "$UNREAD_COUNT" -ge "0" ]; then
    print_pass "Unread count retrieved: $UNREAD_COUNT"
else
    print_fail "Failed to get unread count"
fi

#═══════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
#═══════════════════════════════════════════════════════════════════════════

print_header "TEST SUMMARY"

echo -e "${BLUE}Total Tests:${NC}   $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC}        $PASSED_TESTS"
echo -e "${RED}Failed:${NC}        $FAILED_TESTS"

if [ "$TOTAL_TESTS" -gt "0" ]; then
    PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
    echo -e "${BLUE}Pass Rate:${NC}     ${PASS_RATE}%"
fi

if [ "$FAILED_TESTS" -gt "0" ]; then
    echo -e "\n${RED}Failed Tests:${NC}"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
        echo -e "${RED}  ✗ $test_name${NC}"
    done
    exit 1
else
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
fi
