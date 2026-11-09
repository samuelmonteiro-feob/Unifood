-- script pra criar as tabelas do unifood
-- primeiro cria o banco (rodar sozinho no pgadmin ou no psql):
--   CREATE DATABASE unifood;
-- depois conecta no banco unifood e roda o resto daqui pra baixo

DROP TABLE IF EXISTS itens_pedido;
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS produtos;
DROP TABLE IF EXISTS estabelecimentos;

CREATE TABLE estabelecimentos (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(60) NOT NULL,
  local VARCHAR(30) NOT NULL, -- praca1, praca2PredioD, praca2PredioE, predioF (igual o enum)
  capacidade INTEGER DEFAULT 5,
  aberto BOOLEAN DEFAULT true
);

CREATE TABLE produtos (
  id SERIAL PRIMARY KEY,
  estabelecimento_id INTEGER REFERENCES estabelecimentos(id),
  nome VARCHAR(50) NOT NULL,
  preco NUMERIC(10,2) NOT NULL,
  tempo_preparo INTEGER DEFAULT 5,
  disponivel BOOLEAN DEFAULT true
);

CREATE TABLE pedidos (
  id SERIAL PRIMARY KEY,
  estabelecimento_id INTEGER REFERENCES estabelecimentos(id),
  nome_cliente VARCHAR(60) NOT NULL,
  status VARCHAR(20) DEFAULT 'confirmado',
  cupom VARCHAR(20),
  total NUMERIC(10,2),
  horario_retirada TIMESTAMP,
  criado_em TIMESTAMP DEFAULT now()
);

CREATE TABLE itens_pedido (
  id SERIAL PRIMARY KEY,
  pedido_id INTEGER REFERENCES pedidos(id),
  produto_id INTEGER REFERENCES produtos(id),
  quantidade INTEGER NOT NULL,
  preco_unitario NUMERIC(10,2) NOT NULL,
  observacao VARCHAR(100)
);

-- dados de teste
INSERT INTO estabelecimentos (nome, local, capacidade) VALUES
  ('Mr. John Pizzas', 'praca2PredioE', 5),
  ('Cantina da Tia', 'praca1', 8),
  ('Lanchonete do Prédio F', 'predioF', 4);

INSERT INTO produtos (estabelecimento_id, nome, preco, tempo_preparo) VALUES
  (1, 'Pizza Calabresa (fatia)', 9.50, 6),
  (1, 'Suco Natural', 6.00, 3),
  (1, 'Pastel de Carne', 8.00, 5),
  (2, 'Prato Feito', 18.00, 10),
  (2, 'Coxinha', 5.50, 2),
  (2, 'Refrigerante Lata', 5.00, 1),
  (3, 'X-Burguer', 15.00, 8),
  (3, 'Pão de Queijo', 4.00, 2),
  (3, 'Café', 3.50, 1);
