#!/bin/bash

# Login
ALICE_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice123"}' | jq -r '.access_token')
BOB_TOKEN=$(curl -s -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"username":"bob","password":"bob123"}' | jq -r '.access_token')

# Get channel
CHANNEL_ID=$(curl -s -X GET "http://localhost:8003/channels" -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.channels[0].id')

# Alice posts message
MSG_RESPONSE=$(curl -s -X POST http://localhost:8002/messages \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\": \"$CHANNEL_ID\", \"content\": \"Test message for reaction\", \"type\": \"text\"}")
    
MESSAGE_ID=$(echo $MSG_RESPONSE | jq -r '.id')
echo "Message created: $MESSAGE_ID"

# Wait a bit
sleep 2

# Bob reacts
REACTION=$(curl -s -X POST "http://localhost:8004/messages/$MESSAGE_ID/reactions" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"emoji": "👍"}')
echo "Reaction response: $REACTION"

# Wait for Kafka
sleep 8

# Check Alice's notifications  
echo "Alice's notifications:"
curl -s -X GET "http://localhost:8008/notifications" \
    -H "Authorization: Bearer $ALICE_TOKEN" | jq '.'
