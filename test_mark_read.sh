#!/bin/bash

# Login Alice
ALICE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}' | jq -r '.access_token')

# Get first notification
NOTIF=$(curl -s -X GET "http://localhost:8008/notifications?page_size=1" -H "Authorization: Bearer $ALICE_TOKEN")
echo "Notifications before:"
echo "$NOTIF" | jq '.notifications[0] | {id, is_read}'
echo "Unread count: $(echo "$NOTIF" | jq '.unread_count')"

NOTIF_ID=$(echo "$NOTIF" | jq -r '.notifications[0].id')

# Mark as read
echo "Marking $NOTIF_ID as read..."
MARK_RESULT=$(curl -s -X PUT "http://localhost:8008/notifications/$NOTIF_ID/read" -H "Authorization: Bearer $ALICE_TOKEN")
echo "Mark result:"
echo "$MARK_RESULT" | jq '{id, is_read, read_at}'

# Check again
echo "After marking:"
AFTER=$(curl -s -X GET "http://localhost:8008/notifications?page_size=1" -H "Authorization: Bearer $ALICE_TOKEN")
echo "$AFTER" | jq '.notifications[0] | {id, is_read, read_at}'
echo "Unread count: $(echo "$AFTER" | jq '.unread_count')"
