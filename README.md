
# pedido-estoque-system-infra

Compose local para Kafka/Zookeeper, Redis, os dois bancos PostgreSQL e o Datadog Agent opcional. Este repositório cuida apenas da infraestrutura; os serviços de aplicação e seu Compose ficam em pedido-estoque-system-app.

## Subir a infraestrutura local

Na raiz deste repositório, execute:

    docker compose up -d
    docker compose ps

Aguarde todos os recursos principais ficarem saudáveis. O Compose cria a rede Docker compartilhada pedido-estoque-network, usada pelo Compose de aplicação. Os endereços disponíveis nessa rede são kafka:29092, redis:6379, postgres-pedidos:5432 e postgres-estoque:5432. Do host, as portas publicadas são Kafka 9092, Redis 6379, pedidos 5432 e estoque 5433.

Depois de a infraestrutura ficar saudável, inicie o Compose de aplicações no repositório pedido-estoque-system-app. Os dois repositórios devem estar disponíveis localmente.

Para observabilidade local, configure DD_API_KEY no arquivo .env (copie .env.example) e execute:

    docker compose --profile observability up -d

Configure também o perfil Datadog no .env do repositório de aplicação para habilitar a instrumentação correspondente.

## LocalStack (Secrets Manager e SSM)

Para testar o fluxo com AWS localmente, sem nuvem real, suba o LocalStack com o profile dedicado:

    docker compose --profile localstack up -d
    docker compose ps

O LocalStack fica disponível em `http://localhost:4566` e expõe os serviços `secretsmanager` e `ssm` com credenciais fictícias (`test`/`test`) e região `us-east-1`. Os scripts em `localstack/init/ready.d/` criam, de forma idempotente, os segredos `pedido-estoque/local/pedido-service/db` e `pedido-estoque/local/estoque-service/db` e o parâmetro `/pedido-estoque/local/common/features.datadog.enabled`.

No `.env` do repositório de aplicação, ative o perfil `aws` (por exemplo, `SPRING_PROFILES_ACTIVE=aws,datadog`) e mantenha o endpoint local apontando para o LocalStack. Para usar AWS real, remova ou ajuste o endpoint e utilize credenciais válidas.

Em Linux/macOS, garanta que os scripts de inicialização sejam executáveis:

    chmod +x localstack/init/ready.d/*.sh

## Parar

Pare primeiro o Compose de aplicações; depois, nesta raiz, execute:

    docker compose down

O comando não remove os volumes nomeados dos bancos. Não use a opção -v se quiser manter os dados locais.

## Configuração

Os valores padrão das credenciais e portas são para desenvolvimento local. Este Compose não define a configuração de produção nem endurece a operação dos serviços.