#!/bin/bash

USERNAME=$1
PASSWORD=$2

#                     Get token via client_credentials
TOKEN=$(curl -s -X POST \
  "$KEYCLOAK/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq -r .access_token)

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "Failed to get token"
  exit 1
fi

#                     Check if the user already exists
EXISTING=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK/admin/realms/$REALM/users?username=$USERNAME" | jq length)

if [ "$EXISTING" -gt 0 ]; then
  echo "User $USERNAME already exists"
  exit 0
fi

#                     Create user
CREATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$KEYCLOAK/admin/realms/$REALM/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USERNAME\",
    \"enabled\": true
  }")

#                     Check if the user has been successfully created
if [ "$CREATE_STATUS" != "201" ]; then
  echo "Failed to create user (HTTP $CREATE_STATUS)"
  exit 1
fi

#                     Try to get the user's ID
USER_ID=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK/admin/realms/$REALM/users?username=$USERNAME" | jq -r '.[0].id')

#                     Check if the user's id is successfully created
if [ "$USER_ID" = "null" ] || [ -z "$USER_ID" ]; then
  echo "Failed to retrieve user ID"
  exit 1
fi

#                     Set password
curl -s -X PUT \
  "$KEYCLOAK/admin/realms/$REALM/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"password\",
    \"value\": \"$PASSWORD\",
    \"temporary\": false
  }"

echo "User $USERNAME created successfully"