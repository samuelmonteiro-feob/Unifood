# Unifood

App de pedidos interno da UNIFEOB (retirada no balcão das praças de alimentação). Projeto de faculdade.

- Projeto Flutter/Dart em `dev/unifood1`. Banco PostgreSQL (dump do grupo, PG 18).
- Estilo do código: simples, "de iniciante" (funções soltas, nomes e comentários em português, sem acento nos comentários). Funcional, mas sem arquitetura elaborada.
- Senha do banco fica em `dev/unifood1/lib/banco/config.dart` (no .gitignore). Nunca commitar senha.
- Por enquanto a interface é pelo terminal: `dart run lib/app_terminal.dart`.
- Backend Dart separado em `dev/backend` (banco no Neon). Conecta com o usuário `unifood_backend` (membro do grupo `unifood_api`), URL no `.env` (no .gitignore, modelo em `.env.exemplo`). Credenciais do banco ficam SÓ no backend, nunca no app Flutter.
- O grupo `unifood_api` NÃO tem acesso aos schemas `negocio_teste`/`negocio`: tem acesso a `identity`, `merchant`, `catalog`, `sales`, `payments`, `marketing`, `engagement`, `campus`, `platform`, `common`.

## Regras importantes
Leia `docs/ORIENTACOES.md` antes de mexer em cadastro/login, RA ou pedidos. Resumo:
- RA = 8 dígitos: 2 primeiros = ano de ingresso (2026 → 26), 6 últimos = sequência no ano começando em 000001 (ex.: 26000855). A validação de formato/existência do RA AINDA NÃO deve ser feita (o banco ainda não tem os RAs).
- Cadastro: nome, e-mail, RA, senha. Login: RA, e-mail e senha. Senha em Argon2id (formato PHC).
- Login/cadastro usam o schema `identity` (tabelas reais). Lojas/pedidos ainda usam `negocio_teste` (cópia de teste); as tabelas reais (`merchant`, `catalog`, `sales`) estão vazias.
