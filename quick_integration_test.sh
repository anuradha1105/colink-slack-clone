#!/bin/bash

# Quick Integration Test - No Hangs
# Tests core functionality across all services

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASSED=0
FAILED=0
declare -a ISSUES

test() {
    local name="$1"
    echo -e "${BLUE}TEST:${NC} $name"
}

pass() {
    ((PASSED++))
    echo -e "${GREEN}✓ PASS${NC}"
}

fail() {
    ((FAILED++))
    ISSUES+=("$1")
    echo -e "${RED}✗ FAIL${NC}: $1"
}

echo -e "${CYAN}=== COLINK QUICK INTEGRATION TEST ===${NC}\n"

# Login
test "Authentication"
ALICE=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}')
ALICE_TOKEN=$(echo $ALICE | jq -r '.access_token')
if [ "$ALICE_TOKEN" != "null" ]; then pass; else fail "Alice login failed"; fi

BOB=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"bob","password":"bob123"}')
BOB_TOKEN=$(echo $BOB | jq -r '.access_token')

# Get channel
CHANNELS=$(curl -s http://localhost:8003/channels -H "Authorization: Bearer $ALICE_TOKEN")
CHANNEL_ID=$(echo $CHANNELS | jq -r '.channels[0].id')

# Test Messages
test "Post Message"
MSG=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"Quick test\",\"type\":\"text\"}")
MSG_ID=$(echo $MSG | jq -r '.id')
if [ "$MSG_ID" != "null" ]; then pass; else fail "Message creation failed"; fi

test "Get Messages"
MSGS=$(curl -s "http://localhost:8002/channels/$CHANNEL_ID/messages" -H "Authorization: Bearer $ALICE_TOKEN")
COUNT=$(echo $MSGS | jq '.messages | length')
if [ "$COUNT" -gt "0" ]; then pass; else fail "Get messages failed"; fi

# Test Threads
test "Create Thread (Expected to fail - known issue)"
THREAD=$(curl -s -X POST http://localhost:8005/threads \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"message_id\":\"$MSG_ID\",\"content\":\"Thread test\"}")
if echo "$THREAD" | jq -e '.id' >/dev/null 2>&1; then
    pass
else
    fail "Thread creation - API endpoint issue"
fi

# Test Reactions
test "Add Reaction (May fail - known issue)"
REACTION=$(curl -s -m 5 -X POST "http://localhost:8004/messages/$MSG_ID/reactions" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"emoji":"👍"}' 2>/dev/null)
if echo "$REACTION" | jq -e '.id' >/dev/null 2>&1; then
    pass
else
    fail "Reaction creation - Port 8004 or permissions issue"
fi

# Test Notifications
test "Post Mention for Notification"
MENTION=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CHANNEL_ID\",\"content\":\"@alice quick test\",\"type\":\"text\"}")
echo -e "${YELLOW}Waiting 8s for Kafka...${NC}"
sleep 8

test "Check Mention Notifications"
NOTIFS=$(curl -s "http://localhost:8008/notifications?notification_type=mention" -H "Authorization: Bearer $ALICE_TOKEN")
NOTIF_COUNT=$(echo $NOTIFS | jq '.notifications | length')
if [ "$NOTIF_COUNT" -gt "0" ]; then pass; else fail "Mention notifications not working"; fi

test "Notification Preferences"
PREFS=$(curl -s http://localhost:8008/notifications/preferences -H "Authorization: Bearer $ALICE_TOKEN")
if echo "$PREFS" | jq -e '.mentions' >/dev/null 2>&1; then pass; else fail "Get preferences failed"; fi

test "Mark Notification as Read"
NOTIF_ID=$(echo $NOTIFS | jq -r '.notifications[0].id')
if [ "$NOTIF_ID" != "null" ]; then
    MARK=$(curl -s -X PUT "http://localhost:8008/notifications/$NOTIF_ID/read" -H "Authorization: Bearer $ALICE_TOKEN")
    if [ "$(echo $MARK | jq -r '.is_read')" = "true" ]; then pass; else fail "Mark as read failed"; fi
else
    fail "No notification to mark as read"
fi

# Summary
echo -e "\n${CYAN}=== SUMMARY ===${NC}"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "Pass Rate: $(awk "BEGIN {printf \"%.1f\", ($PASSED/($PASSED+$FAILED))*100}")%"

if [ ${#ISSUES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Known Issues:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "  - $issue"
    done
fi

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    exit 1
fi
