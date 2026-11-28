
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

## Keycloak local (login da aplicação)

O stack inclui um Keycloak para desenvolvimento local, publicado somente no loopback do host em http://localhost:8180. O container também entra na rede pedido-estoque-network com DNS keycloak; o gateway usa essa rota interna para buscar as chaves públicas do realm. A configuração start-dev e as credenciais abaixo são apenas para desenvolvimento local, não para ambientes implantados.

Na primeira execução, copie e edite o arquivo de ambiente:

    Copy-Item .env.example .env
    notepad .env

Troque KEYCLOAK_ADMIN_PASSWORD e mantenha o arquivo .env local. Depois inicie a infraestrutura normalmente:

    docker compose up -d
    docker compose ps

Aguarde o container keycloak ficar saudável. O realm pedido-estoque é importado de keycloak/realm/pedido-estoque-realm.json. Alterações no arquivo de import são aplicadas quando o realm ainda não existe; para reaplicar a configuração em um ambiente descartável, pare e remova somente o container Keycloak antes de subir novamente. Não remova volumes de banco usados pelos outros serviços.

Acesse o console em http://localhost:8180/admin/ com as credenciais KEYCLOAK_ADMIN_USERNAME e KEYCLOAK_ADMIN_PASSWORD. No realm pedido-estoque, crie um usuário de desenvolvimento e defina uma senha local. Não habilite o fluxo Direct Access Grants.

Para autenticar pela collection Insomnia:

1. Em uma requisição protegida, abra Auth e escolha OAuth 2.0 com grant Authorization Code.
2. Configure Authorize URL como http://localhost:8180/realms/pedido-estoque/protocol/openid-connect/auth e Access Token URL como http://localhost:8180/realms/pedido-estoque/protocol/openid-connect/token.
3. Use o client ID pedido-estoque-local, deixe o client secret vazio, defina scope openid e PKCE S256.
4. Use o redirect URI https://app.insomnia.rest/oauth/redirect, entre com o usuário criado no realm e obtenha o token.
5. Copie o access token para a variável token do environment da collection. As requisições enviam esse valor como Authorization: Bearer.

O issuer esperado é http://localhost:8180/realms/pedido-estoque; dentro do Docker, as chaves ficam em http://keycloak:8080/realms/pedido-estoque/protocol/openid-connect/certs. O access token local inclui a audience pedido-estoque-api, exigida pelo gateway. O client público usa Authorization Code com PKCE e não guarda client secret.

Para mudar porta, imagem, hostname do issuer ou credenciais locais, ajuste as variáveis KEYCLOAK_* no .env. A configuração do issuer no ambiente da aplicação deve corresponder exatamente ao claim iss do token.
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

## Cadastro de usuários da aplicação

O Compose cria, após o Keycloak ficar saudável, o cliente confidencial `pedido-estoque-user-registration` no realm `pedido-estoque`, concede apenas a role `manage-users` do `realm-management` e associa o client scope padrão `kc-admin-api`, necessário para o Admin API aceitar o token no Keycloak 26.8. A credencial do administrador é usada somente pelo bootstrap local; o serviço de cadastro usa seu próprio client ID/secret via client credentials.

Defina `KEYCLOAK_USER_REGISTRATION_CLIENT_SECRET` no `.env` local antes de subir os serviços. Use o mesmo valor no `.env` do repositório da aplicação. Esse secret não deve ser enviado ao Git. Para o fluxo local, o novo serviço fica acessível pelo gateway em `POST http://localhost:8080/api/usuarios`; ele não publica porta própria no host.