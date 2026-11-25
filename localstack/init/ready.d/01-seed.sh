#!/bin/sh
set -eu

# Semeia os segredos e o parâmetro global usados pelo fluxo local com o perfil aws.
# Os valores são fictícios e correspondem aos serviços do Compose de infraestrutura.

create_or_update_secret() {
  name="$1"
  value="$2"
  awslocal secretsmanager create-secret --name "$name" --secret-string "$value" >/dev/null 2>&1 \
    || awslocal secretsmanager put-secret-value --secret-id "$name" --secret-string "$value" >/dev/null
}

create_or_update_secret "pedido-estoque/local/pedido-service/db" \
  '{"AWS_DB_URL":"jdbc:postgresql://postgres-pedidos:5432/pedidos_db","AWS_DB_USER":"postgres","AWS_DB_PASSWORD":"postgres"}'

create_or_update_secret "pedido-estoque/local/estoque-service/db" \
  '{"AWS_DB_URL":"jdbc:postgresql://postgres-estoque:5432/estoque_db","AWS_DB_USER":"postgres","AWS_DB_PASSWORD":"postgres"}'

awslocal ssm put-parameter \
  --name "/pedido-estoque/local/common/features.datadog.enabled" \
  --value "false" \
  --type String \
  --overwrite >/dev/null

echo "LocalStack seed concluído."
