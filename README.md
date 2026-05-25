# 🪄 Tons Educativos de Magia

Jogo educativo multiplayer de Match-3 onde combinações de **cores** e **formas geométricas** geram magias únicas. Desenvolvido em Godot 4 com backend em Nakama e banco de dados CockroachDB.

---

## 🛠️ Stack Técnica

### Engine & Linguagem
| Tecnologia | Versão | Uso |
|---|---|---|
| [Godot Engine](https://godotengine.org/) | 4.x | Engine principal |
| GDScript | 2.0 | Linguagem de scripting |

### Backend & Multiplayer
| Tecnologia | Versão | Uso |
|---|---|---|
| [Nakama](https://heroiclabs.com/nakama/) | — | Servidor de jogo (autenticação, sessões, storage, matchmaking) |
| [Nakama Godot SDK](https://github.com/heroiclabs/nakama-godot) | — | Integração Godot ↔ Nakama |

### Banco de Dados
| Tecnologia | Versão | Uso |
|---|---|---|
| [CockroachDB](https://www.cockroachlabs.com/) | — | Banco de dados relacional distribuído (instanciado via Nakama) |

### Testes
| Tecnologia | Versão | Uso |
|---|---|---|
| [GDUnit4](https://github.com/MikeSchulze/gdUnit4) | 4.x | Framework de testes unitários e de integração |

---

## 🧪 Testes

Os testes cobrem a camada de modelos e a integração com o Nakama/CockroachDB:

- `AlunoModel` — validação de dados e persistência
- `ProfessorModel` — validação de dados e persistência
- `PartidaMatch3Model` — validação de dados e persistência
- `LobbySessaoModel` — validação de dados e persistência
- `DesafioQuizModel` — validação de dados e persistência

Para rodar os testes, abra o projeto no Godot e utilize o painel **GdUnit4** na barra inferior.
