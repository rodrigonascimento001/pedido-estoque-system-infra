#!/usr/bin/env bash
# Garante, de forma idempotente, as roles de negócio do realm pedido-estoque:
#   customer: roles padrão do realm (toda conta nova recebe) e atribuída às contas existentes
#   operator: nunca entra nas roles padrão; só é atribuída ao usuário local opcional abaixo
# Também garante o mapper que publica as roles do realm no access token (realm_access.roles).
set -euo pipefail

: "${KEYCLOAK_ADMIN_USERNAME:?Keycloak admin username is required}"
: "${KEYCLOAK_ADMIN_PASSWORD:?Keycloak admin password is required}"

KCADM=/opt/keycloak/bin/kcadm.sh
REALM=pedido-estoque
API_SCOPE=pedido-estoque-api
MAPPER=realm-roles

$KCADM config credentials --server http://keycloak:8080 --realm master \
  --user "$KEYCLOAK_ADMIN_USERNAME" --password "$KEYCLOAK_ADMIN_PASSWORD"

for role in customer operator; do
  if ! $KCADM get "roles/$role" -r "$REALM" >/dev/null 2>&1; then
    $KCADM create roles -r "$REALM" -s "name=$role"
  fi
done

# Toda conta nova (inclusive a criada por POST /api/usuarios) recebe customer.
$KCADM add-roles -r "$REALM" --rname "default-roles-$REALM" --rolename customer

# Contas que já existiam antes das roles passam a ter customer.
$KCADM get users -r "$REALM" -q max=1000 --fields id,username --format csv --noquotes |
  while IFS=, read -r user_id username; do
    case "$username" in
      "" | service-account-*) continue ;;
    esac
    $KCADM add-roles -r "$REALM" --uid "$user_id" --rolename customer
  done

# Realms já importados antes desta mudança não têm o mapper do realm JSON.
SCOPE_UUID=$($KCADM get client-scopes -r "$REALM" -q "name=$API_SCOPE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$SCOPE_UUID" ]; then
  echo "Client scope $API_SCOPE was not found in realm $REALM" >&2
  exit 1
fi
if ! $KCADM get "client-scopes/$SCOPE_UUID/protocol-mappers/models" -r "$REALM" | grep -q "\"$MAPPER\""; then
  $KCADM create "client-scopes/$SCOPE_UUID/protocol-mappers/models" -r "$REALM" \
    -s "name=$MAPPER" \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-usermodel-realm-role-mapper \
    -s consentRequired=false \
    -s 'config."claim.name"=realm_access.roles' \
    -s 'config."jsonType.label"=String' \
    -s 'config."multivalued"=true' \
    -s 'config."access.token.claim"=true' \
    -s 'config."id.token.claim"=false' \
    -s 'config."userinfo.token.claim"=false'
fi

# Usuário operator para desenvolvimento local. Só é criado quando a senha é informada no .env.
if [ -n "${KEYCLOAK_LOCAL_OPERATOR_PASSWORD:-}" ]; then
  OPERATOR_USERNAME="${KEYCLOAK_LOCAL_OPERATOR_USERNAME:-local.operator}"
  if [ -z "$($KCADM get users -r "$REALM" -q "username=$OPERATOR_USERNAME" -q exact=true --fields id --format csv --noquotes)" ]; then
    $KCADM create users -r "$REALM" \
      -s "username=$OPERATOR_USERNAME" \
      -s "email=$OPERATOR_USERNAME@local.test" \
      -s firstName=Local \
      -s lastName=Operator \
      -s enabled=true \
      -s emailVerified=true
    $KCADM set-password -r "$REALM" --username "$OPERATOR_USERNAME" --new-password "$KEYCLOAK_LOCAL_OPERATOR_PASSWORD"
  fi
  $KCADM add-roles -r "$REALM" --uusername "$OPERATOR_USERNAME" --rolename operator
else
  echo "KEYCLOAK_LOCAL_OPERATOR_PASSWORD is empty; skipping the local operator user"
fi
