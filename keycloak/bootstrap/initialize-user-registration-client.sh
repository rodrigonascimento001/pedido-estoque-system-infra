#!/usr/bin/env bash
set -euo pipefail

: "${KEYCLOAK_ADMIN_USERNAME:?Keycloak admin username is required}"
: "${KEYCLOAK_ADMIN_PASSWORD:?Keycloak admin password is required}"
: "${KEYCLOAK_USER_REGISTRATION_CLIENT_SECRET:?Registration client secret is required}"

KCADM=/opt/keycloak/bin/kcadm.sh
REALM=pedido-estoque
CLIENT_ID=pedido-estoque-user-registration
$KCADM config credentials --server http://keycloak:8080 --realm master \
  --user "$KEYCLOAK_ADMIN_USERNAME" --password "$KEYCLOAK_ADMIN_PASSWORD"

CLIENT_UUID=$($KCADM get clients -r "$REALM" -q "clientId=$CLIENT_ID" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$CLIENT_UUID" ]; then
  $KCADM create clients -r "$REALM" \
    -s "clientId=$CLIENT_ID" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s clientAuthenticatorType=client-secret \
    -s serviceAccountsEnabled=true \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s "secret=$KEYCLOAK_USER_REGISTRATION_CLIENT_SECRET"
fi

$KCADM add-roles -r "$REALM" \
  --uusername "service-account-$CLIENT_ID" \
  --cclientid realm-management \
  --rolename manage-users

CLIENT_UUID=$($KCADM get clients -r "$REALM" -q "clientId=$CLIENT_ID" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
ADMIN_SCOPE_UUID=$($KCADM get client-scopes -r "$REALM" -q name=kc-admin-api | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$ADMIN_SCOPE_UUID" ]; then
  echo "Client scope kc-admin-api was not found in realm $REALM" >&2
  exit 1
fi
if ! $KCADM get "clients/$CLIENT_UUID/default-client-scopes" -r "$REALM" | grep -q "\"$ADMIN_SCOPE_UUID\""; then
  $KCADM update "clients/$CLIENT_UUID/default-client-scopes/$ADMIN_SCOPE_UUID" -r "$REALM"
fi
