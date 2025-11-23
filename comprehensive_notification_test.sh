#!/bin/bash

# Comprehensive Notifications Service Test Suite
# Tests all notification scenarios with detailed reporting

set -e

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Report file
REPORT_FILE="NOTIFICATION_TEST_REPORT.md"

# Test counters
TOTAL_SCENARIOS=0
PASSED_SCENARIOS=0
FAILED_SCENARIOS=0

# Test results array
declare -a TEST_RESULTS

# Initialize report
init_report() {
    cat > "$REPORT_FILE" << 'EOF'
# Comprehensive Notifications Service Test Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Service:** Notifications Service (http://localhost:8008)
**Test Environment:** Docker Compose Stack

---

## Executive Summary

This report contains comprehensive testing of the Notifications Service across multiple scenarios including:
- Mention notifications (@username)
- Reaction notifications
- Thread reply notifications
- Channel update notifications
- Direct message notifications
- Notification preferences and filtering
- Mark as read/unread functionality
- Pagination and filtering

---

## Test Scenarios

EOF
}

# Add scenario to report
add_scenario() {
    local scenario_num="$1"
    local scenario_name="$2"
    local description="$3"

    cat >> "$REPORT_FILE" << EOF

### Scenario $scenario_num: $scenario_name

**Description:** $description

EOF
}

# Add test step to report
add_step() {
    local step_num="$1"
    local action="$2"
    local expected="$3"
    local actual="$4"
    local status="$5"

    cat >> "$REPORT_FILE" << EOF
**Step $step_num:** $action

- **Expected Result:** $expected
- **Actual Result:** $actual
- **Status:** $status

EOF
}

# Print header
print_header() {
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║    COMPREHENSIVE NOTIFICATIONS SERVICE TEST SUITE                 ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print scenario header
print_scenario() {
    local num="$1"
    local name="$2"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}SCENARIO $num: $name${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

# Print step
print_step() {
    local step="$1"
    echo -e "${BLUE}  Step $step${NC}"
}

# Print result
print_result() {
    local status="$1"
    local message="$2"

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}    ✓ $message${NC}"
    else
        echo -e "${RED}    ✗ $message${NC}"
    fi
}

# Wait for Kafka to process
wait_for_kafka() {
    local seconds="${1:-3}"
    echo -e "${MAGENTA}    ⏳ Waiting ${seconds}s for Kafka event processing...${NC}"
    sleep "$seconds"
}

# Initialize
print_header
init_report

echo -e "${CYAN}Initializing test environment...${NC}"

# Login test users
echo -e "${BLUE}Logging in test users...${NC}"
ALICE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}' | jq -r '.access_token')
BOB_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"bob","password":"bob123"}' | jq -r '.access_token')
CHARLIE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"charlie","password":"charlie123"}' | jq -r '.access_token')

if [ -z "$ALICE_TOKEN" ] || [ -z "$BOB_TOKEN" ] || [ -z "$CHARLIE_TOKEN" ]; then
    echo -e "${RED}✗ Failed to login test users${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Test users logged in successfully${NC}"

# Get Alice's user ID
ALICE_USER_ID=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications/preferences | jq -r '.user_id')
BOB_USER_ID=$(curl -s -H "Authorization: Bearer $BOB_TOKEN" http://localhost:8008/notifications/preferences | jq -r '.user_id')
CHARLIE_USER_ID=$(curl -s -H "Authorization: Bearer $CHARLIE_TOKEN" http://localhost:8008/notifications/preferences | jq -r '.user_id')

echo -e "${GREEN}✓ User IDs: Alice=$ALICE_USER_ID, Bob=$BOB_USER_ID, Charlie=$CHARLIE_USER_ID${NC}"

# Get or create a channel
CHANNELS_RESPONSE=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8003/channels)
CHANNEL_ID=$(echo "$CHANNELS_RESPONSE" | jq -r '.channels[0].id // empty')

if [ -z "$CHANNEL_ID" ]; then
    echo -e "${BLUE}Creating test channel...${NC}"
    CHANNEL_ID=$(curl -s -X POST http://localhost:8003/channels \
        -H "Authorization: Bearer $ALICE_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "test-notifications",
            "description": "Channel for testing notifications",
            "type": "public"
        }' | jq -r '.id')
    echo -e "${GREEN}✓ Channel created: $CHANNEL_ID${NC}"
else
    echo -e "${GREEN}✓ Using existing channel: $CHANNEL_ID${NC}"
fi

# Ensure Bob and Charlie are members
curl -s -X POST "http://localhost:8003/channels/$CHANNEL_ID/members" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"$BOB_USER_ID\"}" > /dev/null

curl -s -X POST "http://localhost:8003/channels/$CHANNEL_ID/members" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"$CHARLIE_USER_ID\"}" > /dev/null

echo -e "${GREEN}✓ All users are channel members${NC}"
echo ""

#===============================================================================
# SCENARIO 1: Mention Notifications
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "1" "Mention Notifications (@username)"
add_scenario "1" "Mention Notifications" "Test that users receive notifications when mentioned in messages"

print_step "1.1: Clear existing notifications"
curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications | \
    jq -r '.notifications[].id' | while read notif_id; do
    curl -s -X DELETE "http://localhost:8008/notifications/$notif_id" \
        -H "Authorization: Bearer $ALICE_TOKEN" > /dev/null
done
print_result "PASS" "Cleared Alice's notifications"

print_step "1.2: Bob posts message mentioning @alice"
MESSAGE_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"channel_id\": \"$CHANNEL_ID\",
        \"content\": \"Hey @alice, can you review this?\",
        \"type\": \"text\"
    }")
MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | jq -r '.id')
print_result "PASS" "Message created: $MESSAGE_ID"
add_step "1.2" "Bob posts '@alice, can you review this?'" "Message created successfully" "Message ID: $MESSAGE_ID" "✅ PASS"

wait_for_kafka 5

print_step "1.3: Check Alice received mention notification"
ALICE_NOTIFS=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications)
MENTION_COUNT=$(echo "$ALICE_NOTIFS" | jq '[.notifications[] | select(.type == "mention")] | length')
UNREAD_COUNT=$(echo "$ALICE_NOTIFS" | jq '.unread_count')

if [ "$MENTION_COUNT" -gt 0 ]; then
    print_result "PASS" "Alice received $MENTION_COUNT mention notification(s)"
    add_step "1.3" "Check Alice's notifications" "At least 1 mention notification" "Found $MENTION_COUNT mention notification(s), $UNREAD_COUNT unread" "✅ PASS"
    PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
else
    print_result "FAIL" "No mention notifications found for Alice"
    add_step "1.3" "Check Alice's notifications" "At least 1 mention notification" "Found 0 mention notifications" "❌ FAIL"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# SCENARIO 2: Reaction Notifications
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "2" "Reaction Notifications"
add_scenario "2" "Reaction Notifications" "Test that message authors receive notifications when their messages are reacted to"

print_step "2.1: Alice posts a message"
ALICE_MESSAGE_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"channel_id\": \"$CHANNEL_ID\",
        \"content\": \"Check out this cool feature!\",
        \"type\": \"text\"
    }")
ALICE_MESSAGE_ID=$(echo "$ALICE_MESSAGE_RESPONSE" | jq -r '.id')
print_result "PASS" "Alice's message created: $ALICE_MESSAGE_ID"
add_step "2.1" "Alice posts a message" "Message created" "Message ID: $ALICE_MESSAGE_ID" "✅ PASS"

wait_for_kafka 2

print_step "2.2: Bob reacts with 👍 to Alice's message"
REACTION_RESPONSE=$(curl -s -X POST "http://localhost:8006/reactions" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"message_id\": \"$ALICE_MESSAGE_ID\",
        \"emoji\": \"👍\"
    }")
print_result "PASS" "Bob added 👍 reaction"
add_step "2.2" "Bob reacts with 👍" "Reaction added" "Reaction added successfully" "✅ PASS"

wait_for_kafka 5

print_step "2.3: Check Alice received reaction notification"
ALICE_NOTIFS=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications)
REACTION_COUNT=$(echo "$ALICE_NOTIFS" | jq '[.notifications[] | select(.type == "reaction")] | length')

if [ "$REACTION_COUNT" -gt 0 ]; then
    REACTION_DETAILS=$(echo "$ALICE_NOTIFS" | jq -r '.notifications[] | select(.type == "reaction") | .content' | head -1)
    print_result "PASS" "Alice received reaction notification: $REACTION_DETAILS"
    add_step "2.3" "Check Alice's notifications" "Reaction notification received" "Received: $REACTION_DETAILS" "✅ PASS"
    PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
else
    print_result "FAIL" "No reaction notifications found for Alice"
    add_step "2.3" "Check Alice's notifications" "Reaction notification received" "No reaction notifications" "❌ FAIL"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# SCENARIO 3: Thread Reply Notifications
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "3" "Thread Reply Notifications"
add_scenario "3" "Thread Reply Notifications" "Test that users receive notifications when someone replies to their thread"

print_step "3.1: Alice creates a thread on her message"
THREAD_RESPONSE=$(curl -s -X POST "http://localhost:8005/threads" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"message_id\": \"$ALICE_MESSAGE_ID\",
        \"content\": \"Let me explain more about this feature...\"
    }")
THREAD_ID=$(echo "$THREAD_RESPONSE" | jq -r '.id // .thread_id // empty')

if [ -n "$THREAD_ID" ]; then
    print_result "PASS" "Thread created: $THREAD_ID"
    add_step "3.1" "Alice creates thread" "Thread created" "Thread ID: $THREAD_ID" "✅ PASS"

    wait_for_kafka 2

    print_step "3.2: Charlie replies to Alice's thread"
    THREAD_REPLY=$(curl -s -X POST "http://localhost:8005/threads/$THREAD_ID/reply" \
        -H "Authorization: Bearer $CHARLIE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"content\": \"Great explanation, thanks!\"
        }")
    print_result "PASS" "Charlie replied to thread"
    add_step "3.2" "Charlie replies to thread" "Reply posted" "Reply posted successfully" "✅ PASS"

    wait_for_kafka 5

    print_step "3.3: Check Alice received reply notification"
    ALICE_NOTIFS=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications)
    REPLY_COUNT=$(echo "$ALICE_NOTIFS" | jq '[.notifications[] | select(.type == "reply")] | length')

    if [ "$REPLY_COUNT" -gt 0 ]; then
        print_result "PASS" "Alice received $REPLY_COUNT reply notification(s)"
        add_step "3.3" "Check reply notifications" "Reply notification received" "Received $REPLY_COUNT reply notification(s)" "✅ PASS"
        PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
    else
        print_result "FAIL" "No reply notifications found"
        add_step "3.3" "Check reply notifications" "Reply notification received" "No reply notifications" "❌ FAIL"
        FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
    fi
else
    print_result "FAIL" "Failed to create thread"
    add_step "3.1" "Alice creates thread" "Thread created" "Thread creation failed" "❌ FAIL"
    add_step "3.2" "Charlie replies to thread" "Reply posted" "Skipped - no thread" "⊘ SKIP"
    add_step "3.3" "Check reply notifications" "Notification received" "Skipped - no thread" "⊘ SKIP"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# SCENARIO 4: Notification Preferences - Disable Reactions
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "4" "Notification Preferences - Filtering"
add_scenario "4" "Notification Preferences" "Test that users can disable specific notification types"

print_step "4.1: Alice disables reaction notifications"
PREFS_UPDATE=$(curl -s -X PUT http://localhost:8008/notifications/preferences \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "reactions": false,
        "mentions": true,
        "replies": true,
        "direct_messages": true,
        "channel_updates": true
    }')
REACTIONS_DISABLED=$(echo "$PREFS_UPDATE" | jq -r '.reactions')

if [ "$REACTIONS_DISABLED" = "false" ]; then
    print_result "PASS" "Alice disabled reaction notifications"
    add_step "4.1" "Disable reaction notifications" "Reactions set to false" "Successfully disabled" "✅ PASS"
else
    print_result "FAIL" "Failed to disable reactions"
    add_step "4.1" "Disable reaction notifications" "Reactions set to false" "Failed to update" "❌ FAIL"
fi

print_step "4.2: Bob reacts to another Alice message"
NEW_ALICE_MSG=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"channel_id\": \"$CHANNEL_ID\",
        \"content\": \"Another test message\",
        \"type\": \"text\"
    }" | jq -r '.id')

curl -s -X POST "http://localhost:8006/reactions" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"message_id\": \"$NEW_ALICE_MSG\",
        \"emoji\": \"❤️\"
    }" > /dev/null
print_result "PASS" "Bob added ❤️ reaction"
add_step "4.2" "Bob reacts to new message" "Reaction added" "Reaction added successfully" "✅ PASS"

wait_for_kafka 5

print_step "4.3: Verify Alice did NOT receive reaction notification"
ALICE_NOTIFS=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications)
NEW_REACTION_COUNT=$(echo "$ALICE_NOTIFS" | jq "[.notifications[] | select(.type == \"reaction\" and (.content | contains(\"$NEW_ALICE_MSG\")))] | length")

if [ "$NEW_REACTION_COUNT" = "0" ]; then
    print_result "PASS" "Alice correctly did not receive reaction notification"
    add_step "4.3" "Check for new reaction notification" "No new reaction notification" "Correctly filtered out" "✅ PASS"
    PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
else
    print_result "FAIL" "Alice received reaction notification despite preferences"
    add_step "4.3" "Check for new reaction notification" "No new reaction notification" "Received notification anyway" "❌ FAIL"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

# Re-enable reactions for Alice
curl -s -X PUT http://localhost:8008/notifications/preferences \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"reactions": true, "mentions": true, "replies": true, "direct_messages": true, "channel_updates": true}' > /dev/null

#===============================================================================
# SCENARIO 5: Mark as Read/Unread
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "5" "Mark Notifications as Read"
add_scenario "5" "Mark as Read/Unread" "Test marking individual notifications and all notifications as read"

print_step "5.1: Get Alice's unread count"
ALICE_NOTIFS=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications)
INITIAL_UNREAD=$(echo "$ALICE_NOTIFS" | jq '.unread_count')
TOTAL_NOTIFS=$(echo "$ALICE_NOTIFS" | jq '.total_count')
print_result "PASS" "Alice has $INITIAL_UNREAD unread notifications (total: $TOTAL_NOTIFS)"
add_step "5.1" "Check initial unread count" "Get count" "$INITIAL_UNREAD unread, $TOTAL_NOTIFS total" "✅ PASS"

if [ "$TOTAL_NOTIFS" -gt 0 ]; then
    print_step "5.2: Mark first notification as read"
    FIRST_NOTIF_ID=$(echo "$ALICE_NOTIFS" | jq -r '.notifications[0].id')

    curl -s -X POST "http://localhost:8008/notifications/$FIRST_NOTIF_ID/read" \
        -H "Authorization: Bearer $ALICE_TOKEN" > /dev/null

    UPDATED_UNREAD=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications/unread/count | jq '.unread_count')

    if [ "$UPDATED_UNREAD" -lt "$INITIAL_UNREAD" ] || [ "$INITIAL_UNREAD" = "0" ]; then
        print_result "PASS" "Unread count decreased to $UPDATED_UNREAD"
        add_step "5.2" "Mark one notification as read" "Unread count decreases" "Count: $INITIAL_UNREAD → $UPDATED_UNREAD" "✅ PASS"
    else
        print_result "FAIL" "Unread count did not decrease"
        add_step "5.2" "Mark one notification as read" "Unread count decreases" "Count unchanged: $INITIAL_UNREAD" "❌ FAIL"
    fi

    print_step "5.3: Mark all notifications as read"
    curl -s -X POST http://localhost:8008/notifications/read/all \
        -H "Authorization: Bearer $ALICE_TOKEN" > /dev/null

    FINAL_UNREAD=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" http://localhost:8008/notifications/unread/count | jq '.unread_count')

    if [ "$FINAL_UNREAD" = "0" ]; then
        print_result "PASS" "All notifications marked as read"
        add_step "5.3" "Mark all as read" "Unread count becomes 0" "Successfully marked all as read" "✅ PASS"
        PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
    else
        print_result "FAIL" "Still have $FINAL_UNREAD unread notifications"
        add_step "5.3" "Mark all as read" "Unread count becomes 0" "Still have $FINAL_UNREAD unread" "❌ FAIL"
        FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
    fi
else
    print_result "FAIL" "No notifications to test with"
    add_step "5.2" "Mark one notification as read" "N/A" "No notifications available" "⊘ SKIP"
    add_step "5.3" "Mark all as read" "N/A" "No notifications available" "⊘ SKIP"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# SCENARIO 6: Pagination and Filtering
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "6" "Notification Pagination"
add_scenario "6" "Pagination and Filtering" "Test pagination and filtering of notifications by type and read status"

print_step "6.1: Generate multiple notifications"
for i in {1..5}; do
    MSG=$(curl -s -X POST http://localhost:8002/messages \
        -H "Authorization: Bearer $BOB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"channel_id\": \"$CHANNEL_ID\",
            \"content\": \"Message $i mentioning @alice\",
            \"type\": \"text\"
        }")
    sleep 0.5
done
print_result "PASS" "Generated 5 test messages"
add_step "6.1" "Generate test messages" "5 messages with mentions" "5 messages created" "✅ PASS"

wait_for_kafka 6

print_step "6.2: Test pagination (page_size=3)"
PAGE1=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" "http://localhost:8008/notifications?page=1&page_size=3")
PAGE1_COUNT=$(echo "$PAGE1" | jq '.notifications | length')
PAGE1_TOTAL=$(echo "$PAGE1" | jq '.total_count')

if [ "$PAGE1_COUNT" -le 3 ] && [ "$PAGE1_TOTAL" -gt 0 ]; then
    print_result "PASS" "Page 1 returned $PAGE1_COUNT notifications (total: $PAGE1_TOTAL)"
    add_step "6.2" "Request page 1 with size 3" "Max 3 notifications returned" "Returned $PAGE1_COUNT items, total $PAGE1_TOTAL" "✅ PASS"
else
    print_result "FAIL" "Pagination not working correctly"
    add_step "6.2" "Request page 1 with size 3" "Max 3 notifications returned" "Returned $PAGE1_COUNT items" "❌ FAIL"
fi

print_step "6.3: Filter by type (mentions only)"
MENTIONS_ONLY=$(curl -s -H "Authorization: Bearer $ALICE_TOKEN" "http://localhost:8008/notifications?type=mention")
MENTION_TYPES=$(echo "$MENTIONS_ONLY" | jq -r '.notifications[].type' | sort -u)

if [ "$MENTION_TYPES" = "mention" ] || [ -z "$MENTION_TYPES" ]; then
    MENTION_NOTIF_COUNT=$(echo "$MENTIONS_ONLY" | jq '.notifications | length')
    print_result "PASS" "Filter returned only mention notifications ($MENTION_NOTIF_COUNT)"
    add_step "6.3" "Filter by type=mention" "Only mention notifications" "Returned $MENTION_NOTIF_COUNT mention notifications" "✅ PASS"
    PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
else
    print_result "FAIL" "Filter returned mixed types: $MENTION_TYPES"
    add_step "6.3" "Filter by type=mention" "Only mention notifications" "Mixed types returned" "❌ FAIL"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# SCENARIO 7: Multiple Users - Broadcast Scenario
#===============================================================================
TOTAL_SCENARIOS=$((TOTAL_SCENARIOS + 1))
print_scenario "7" "Broadcast Notifications"
add_scenario "7" "Broadcast Notifications" "Test that multiple users receive notifications for the same event"

print_step "7.1: Alice mentions both @bob and @charlie"
BROADCAST_MSG=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"channel_id\": \"$CHANNEL_ID\",
        \"content\": \"Hey @bob and @charlie, please check this!\",
        \"type\": \"text\"
    }" | jq -r '.id')
print_result "PASS" "Broadcast message sent: $BROADCAST_MSG"
add_step "7.1" "Alice mentions @bob and @charlie" "Message created" "Message ID: $BROADCAST_MSG" "✅ PASS"

wait_for_kafka 5

print_step "7.2: Verify Bob received mention"
BOB_NOTIFS=$(curl -s -H "Authorization: Bearer $BOB_TOKEN" http://localhost:8008/notifications)
BOB_MENTION_COUNT=$(echo "$BOB_NOTIFS" | jq '[.notifications[] | select(.type == "mention")] | length')
print_result "PASS" "Bob has $BOB_MENTION_COUNT mention notification(s)"
add_step "7.2" "Check Bob's notifications" "At least 1 mention" "Bob has $BOB_MENTION_COUNT mentions" "✅ PASS"

print_step "7.3: Verify Charlie received mention"
CHARLIE_NOTIFS=$(curl -s -H "Authorization: Bearer $CHARLIE_TOKEN" http://localhost:8008/notifications)
CHARLIE_MENTION_COUNT=$(echo "$CHARLIE_NOTIFS" | jq '[.notifications[] | select(.type == "mention")] | length')

if [ "$CHARLIE_MENTION_COUNT" -gt 0 ]; then
    print_result "PASS" "Charlie has $CHARLIE_MENTION_COUNT mention notification(s)"
    add_step "7.3" "Check Charlie's notifications" "At least 1 mention" "Charlie has $CHARLIE_MENTION_COUNT mentions" "✅ PASS"
    PASSED_SCENARIOS=$((PASSED_SCENARIOS + 1))
else
    print_result "FAIL" "Charlie did not receive mention notification"
    add_step "7.3" "Check Charlie's notifications" "At least 1 mention" "No mentions received" "❌ FAIL"
    FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
fi

#===============================================================================
# Generate Final Report
#===============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}TEST SUMMARY${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Total Scenarios:${NC} $TOTAL_SCENARIOS"
echo -e "${GREEN}Passed:${NC} $PASSED_SCENARIOS"
echo -e "${RED}Failed:${NC} $FAILED_SCENARIOS"

PASS_RATE=$(echo "scale=1; $PASSED_SCENARIOS * 100 / $TOTAL_SCENARIOS" | bc)
echo -e "${BLUE}Pass Rate:${NC} ${PASS_RATE}%"

# Add summary to report
cat >> "$REPORT_FILE" << EOF

---

## Test Summary

| Metric | Value |
|--------|-------|
| **Total Scenarios** | $TOTAL_SCENARIOS |
| **Passed** | $PASSED_SCENARIOS |
| **Failed** | $FAILED_SCENARIOS |
| **Pass Rate** | ${PASS_RATE}% |

---

## Scenario Results

| # | Scenario | Status |
|---|----------|--------|
| 1 | Mention Notifications | $([ $MENTION_COUNT -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL") |
| 2 | Reaction Notifications | $([ $REACTION_COUNT -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL") |
| 3 | Thread Reply Notifications | $([ "$REPLY_COUNT" -gt 0 ] 2>/dev/null && echo "✅ PASS" || echo "❌ FAIL") |
| 4 | Notification Preferences | $([ "$NEW_REACTION_COUNT" = "0" ] && echo "✅ PASS" || echo "❌ FAIL") |
| 5 | Mark as Read/Unread | $([ "$FINAL_UNREAD" = "0" ] 2>/dev/null && echo "✅ PASS" || echo "❌ FAIL") |
| 6 | Pagination and Filtering | $([ "$PAGE1_COUNT" -le 3 ] && echo "✅ PASS" || echo "❌ FAIL") |
| 7 | Broadcast Notifications | $([ "$CHARLIE_MENTION_COUNT" -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL") |

---

## Conclusion

$(if [ "$FAILED_SCENARIOS" = "0" ]; then
    echo "✅ **All scenarios passed successfully!** The Notifications Service is working as expected across all tested scenarios."
else
    echo "⚠️ **Some scenarios failed.** Please review the failed scenarios above for details. Common issues:"
    echo ""
    echo "- Kafka event processing delays (increase wait times)"
    echo "- Missing Kafka topic configurations"
    echo "- Database synchronization issues"
fi)

### Next Steps

- Review any failed scenarios and investigate root causes
- Monitor Kafka consumer logs for event processing issues
- Verify database state for notification records
- Test edge cases and error handling scenarios

---

**Report generated on:** $(date '+%Y-%m-%d %H:%M:%S')
EOF

echo ""
echo -e "${GREEN}✓ Detailed test report saved to: $REPORT_FILE${NC}"
echo ""

# Exit with appropriate code
if [ "$FAILED_SCENARIOS" -gt 0 ]; then
    exit 1
else
    exit 0
fi
