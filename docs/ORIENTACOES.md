# Orientações para implementações futuras

Anotações do grupo sobre regras que **ainda não foram implementadas** e sobre detalhes do banco que precisam de atenção.

---

## 1. RA dos estudantes

### Regra da universidade

O RA tem **8 dígitos**:

| Parte | Dígitos | Significado |
|---|---|---|
| Ano de ingresso | 2 primeiros | Os dois últimos dígitos do ano em que o aluno entrou. Ingressantes de 2026 → `26`. |
| Sequência | 6 últimos | Número único do aluno dentro do ano, em ordem de ingresso, começando em `000001`. |

Exemplos:
- `26000001` → primeiro ingressante de 2026
- `26000855` → 855º ingressante de 2026
- `26001088` → 1088º ingressante de 2026

### Situação atual (o que está implementado)

- No **cadastro**, o RA é obrigatório, mas o formato **não é verificado**, porque o banco ainda não tem os RAs dos alunos registrados. O app só confere se o RA não está vazio e se não existe outra conta com o mesmo RA.
- No **login**, o RA precisa ser igual ao que foi cadastrado para aquele e-mail.
- O RA fica salvo em `identity.users.ra`.

### Quando for implementar a verificação

1. **Validar o formato** (em `Usuario.validarRa`, arquivo `lib/models/usuario.dart`):
   - exatamente 8 dígitos (`^[0-9]{8}$`);
   - ano (2 primeiros dígitos) não pode ser maior que o ano atual;
   - sequência (6 últimos) não pode ser `000000`.

   Sugestão de código:

   ```dart
   static String validarRa(String ra) {
     var limpo = ra.trim();
     if (!RegExp(r'^[0-9]{8}$').hasMatch(limpo)) {
       throw const ValidacaoException('O RA deve ter 8 números. Exemplo: 26000855');
     }
     var ano = int.parse(limpo.substring(0, 2));
     var sequencia = int.parse(limpo.substring(2));
     var anoAtual = DateTime.now().year % 100;
     if (ano > anoAtual) {
       throw const ValidacaoException('O ano de ingresso do RA é inválido.');
     }
     if (sequencia == 0) {
       throw const ValidacaoException('RA inválido.');
     }
     return limpo;
   }
   ```

2. **Conferir se o RA existe** na base de alunos da universidade, quando ela estiver no banco.
3. **Criar o vínculo** do aluno com o campus em `identity.campus_affiliations` (`affiliation_type = 'student'`, `registration_number = RA`). Ao verificar o vínculo, rodar `identity.verify_affiliation(...)`: isso deixa o vínculo como `verified` e a conta como `active`.

### ⚠️ Atenção: o banco só aceita RA que começa com 26

Hoje o banco fixa o ano **26** em três lugares, então alunos que entraram em outros anos (ex: `25001234`) seriam recusados:

| Onde | Regra atual |
|---|---|
| Domínio `common.ra_unifeob` | `^26[0-9]{6}$` |
| Constraint `ck_campus_affiliations_student_ra` (tabela `identity.campus_affiliations`) | `^26[0-9]{6}$` |
| Função `identity.login_lookup` | `^26[0-9]{6}$` |

Antes de ativar a verificação, trocar por `^[0-9]{8}$` (mais as regras de ano e sequência). Exemplo para o domínio:

```sql
ALTER DOMAIN common.ra_unifeob DROP CONSTRAINT ck_ra_unifeob;
ALTER DOMAIN common.ra_unifeob ADD CONSTRAINT ck_ra_unifeob CHECK (VALUE ~ '^[0-9]{2}[0-9]{6}$' AND right(VALUE, 6) <> '000000');
```

### Outras observações sobre o RA no banco

- A coluna `identity.users.ra` **não tem regra de valor único**. O app confere isso antes de cadastrar, mas o ideal é criar um índice:
  ```sql
  CREATE UNIQUE INDEX uq_users_ra ON identity.users (ra) WHERE deleted_at IS NULL;
  ```
- A função `identity.register_user(...)` **não preenche a coluna `ra`**, que é `NOT NULL`. Do jeito que está, ela falha. Por isso o app faz os INSERTs direto (ver `lib/banco/usuarios.dart`). Se a função for corrigida para receber o RA, o app pode passar a usá-la.

---

## 2. Cadastro e login (como funciona hoje)

- **Cadastro** pede nome, e-mail, RA e senha, e grava em:
  - `identity.users` (nome, e-mail, RA; status começa como `pending_verification`);
  - `identity.auth_identities` (`provider = 'password'`, `provider_subject` = e-mail em minúsculo, `password_hash`);
  - `identity.user_consents` (aceite dos termos de uso e da política de privacidade vigentes).
- **Login** pede RA, e-mail e senha. Quando dá certo, abre uma sessão com a função `identity.start_session(...)`, que também atualiza `last_login_at`. Ao sair, a sessão recebe `revoked_at`.
- **Senha:** nunca é salva. O banco guarda só o hash **Argon2id** no formato padrão `$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>` (ver `lib/banco/senha.dart`). Qualquer biblioteca de Argon2 (Node, Python...) consegue conferir esse hash.
- **E-mail:** não tem um padrão da universidade, só o formato básico (`algo@algo.algo`, até 254 caracteres), igual ao domínio `common.email_address`. Maiúsculas e minúsculas não fazem diferença.
- Contas `suspended` ou `anonymized` não conseguem entrar.

---

## 3. Lojas e pedidos

- As **tabelas reais** de lojas, produtos e pedidos (`merchant.stores`, `catalog.products`, `sales.orders`...) estão **vazias**. O app ainda lê e grava no schema `negocio_teste`, que é uma cópia com dados de teste.
- Para fazer pedido nas tabelas reais (função `sales.place_order`), o usuário precisa estar **ativo** e ter **vínculo verificado** com o campus (configuração `require_verified_affiliation = true` em `platform.app_settings`). Ou seja: depende da verificação do RA (seção 1).
- Os pedidos salvos em `negocio_teste.pedidos` guardam só o **primeiro nome** do cliente, igual à view `negocio.pedidos`.
