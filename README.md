# Agentic RAG com Qdrant & LangGraph (Produção)

Este módulo representa o projeto final da nossa trilha de *Retrieval-Augmented Generation* (RAG). Aqui, elevamos o sistema RAG tradicional para uma arquitetura **Agentic RAG**, pronta para produção, que une a força de bancos de dados vetoriais locais ([Qdrant](https://qdrant.tech/documentation/)), frameworks de agentes ([LangGraph](https://langchain-ai.github.io/langgraph/) e [LangChain](https://python.langchain.com/)), e uma API moderna ([FastAPI](https://fastapi.tiangolo.com/)).

## 🎯 Objetivo Arquitetural

No RAG Tradicional, o fluxo é fixo: o usuário pergunta, o sistema sempre busca no banco de dados vetorial, anexa o contexto e envia ao LLM.

**No nosso projeto (Agentic RAG):** 
Nós utilizamos o **[LangGraph](https://langchain-ai.github.io/langgraph/)** para criar um Agente (LLM) que toma decisões. Através de *Tools* (ferramentas), o modelo decide proativamente:
1. **Devo responder diretamente?** (Para bate-papo, saudações "Olá, bom dia").
2. **Devo invocar a ferramenta de busca?** (Para perguntas técnicas ou sobre o acervo documental).

Isso resulta em um sistema mais inteligente, que não gasta tokens e tempo fazendo buscas desnecessárias, mas realiza *queries* cirúrgicas na base vetorial quando precisada de contexto.

## 🛠️ Stack Tecnológica e Ferramentas

O ecossistema que construímos envolve as seguintes tecnologias:

*   **[FastAPI](https://fastapi.tiangolo.com/)**: Servidor web assíncrono hiper-rápido, provendo os endpoints da nossa aplicação Restful.
*   **[Qdrant](https://qdrant.tech/documentation/)**: Nosso Banco de Dados Vetorial *Open Source*. Estamos rodando o [Qdrant](https://qdrant.tech/documentation/) via [Docker](https://docs.docker.com/) localmente (porta 6333) para persistir nossos embeddings de alta dimensão.
*   **[LangChain](https://python.langchain.com/) & [LangGraph](https://langchain-ai.github.io/langgraph/)**: Orquestração do agente. O `LangGraph` gerencia o Estado da nossa conversa (StateGraph) e o ciclo dinâmico contínuo entre invocações diretas ao LLM e o *ToolNode* (nossa ferramenta de busca).
*   **[OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings) (text-embedding-3-large)**: Criação de vetores para mapeamento semântico dos textos.
*   **[OpenAI LLM](https://platform.openai.com/docs/models) (gpt-4.1-mini)**: O "Cérebro" do Agente, encarregado de interpretar requests e executar chamadas da ferramenta de retrieve. (Há também um `gpt-4.1` instanciado em `llm_models.py`.)
*   **[Langfuse](https://langfuse.com/docs)**: Plataforma de Observabilidade e Monitoramento de LLMs. Usado através de callbacks para traçar e analisar cada token gerado e tempo de inferência nas requisições.

## 🗂️ Estrutura do Projeto

```text
rag-production/
├── index.html                  # Interface web (chat + upload de documentos).
├── main.py                     # Entrypoint do Uvicorn que sobe a aplicação FastAPI.
├── docker-compose.yml          # Sobe o Qdrant localmente (portas 6333/6334).
├── Makefile                    # Atalhos de desenvolvimento (`make dev`, `make down`, ...).
├── .env.example                # Modelo das variáveis de ambiente.
├── src/
│   ├── api.py                  # Definição do FastAPI, CORS, /health e inclusão dos Routers.
│   ├── models.py               # Contratos de dados (Pydantic Models) para as Requisições/Respostas.
│   ├── settings.py             # Gerenciamento de Variáveis de Ambiente e chaves de API.
│   ├── pdf_utils.py            # Utilitários de extração de texto em memória (PyMuPDF - fitz).
│   ├── customlogger.py         # Configuração de Logs padronizado para console.
│   ├── chat/
│   │   ├── chat.py             # Core do Agentic RAG: Graph State, Agente LLM, e a Tool de Retrieve.
│   │   ├── llm_models.py       # Instanciação centralizada das LLMs e Embeddings (OpenAI).
│   │   └── qdrant.py           # Clientes global sync/async de conexão com o Qdrant.
│   ├── embedder/
│   │   ├── client.py           # Operações de Banco (criar/listar collection, Upsert Vetores, etc.).
│   │   └── processor.py        # Processamento Inteligente: Chunking Dinâmico, Extração Meta-Info + LLM.
│   └── routers/
│       ├── chat.py             # Endpoint /chat/ask -> Conecta o cliente Frontend ao agente.
│       └── qdrant.py           # Router principal: coleções e documentos (criar, listar, upload, apagar).
```

## ⚙️ Novidades e Funcionalidades Core

### 1. Ingestão Dinâmica de Documentos
Foi criado um motor flexível no `processor.py` para ingestão:
*   Os administradores podem através de Endpoints subir PDFs diretamente para *Collections* específicas.
*   Pode ser decidido em tempo-de-requisição se usaremos divisores Recursivos (`RecursiveCharacterTextSplitter`) ou por blocos fechados.
*   Tamanho de Chunks, Overlap e tokenizadores locais (`tiktoken`) são parametrizados via API dinamicamente.

### 2. Auto-Extração de Metadados via LLM
Ao enviar um documento para o vetor, o sistema lê automaticamente a primeira página e solicita dinamicamente a outro LLM (via `with_structured_output`) que emita:
*   `classificacao`: Qual o tipo do arquivo em 3 palavras.
*   `descricao`: Resumo funcional em 2 frases.
* Isso entra como metadados enriquecidos no banco, facilitando filtros e aumentando contexto de leitura futura.

### 3. Agente com Tool Calling e Multi-Collections
O chat mudou radicalmente nesta versão. Usamos a magia do `StateGraph` do [LangGraph](https://langchain-ai.github.io/langgraph/).
*   O estado gerencia a lista de mensagens (`messages`) e também o arquivo contextual (`file_context`).
*   O Endpoints aceita no payload `collection_name`, passando dinamicamente essa variável na configuração de Runtime do [LangGraph](https://langchain-ai.github.io/langgraph/) para a ferramenta `retrieve_documents`. Assim o usuário pesquisa na base que quiser sem reescrever código.
*   **O Agente pensa:** Se a requisição requerer, o agente ativa a *tool*, varre o banco, junta o resultado retornado pela Tool, formata com citações ("Fonte: arquivo X, pág Y") e molda a resposta final.

### 4. Observabilidade Real ([Langfuse](https://langfuse.com/docs))
Cada chamada da rota `/chat/ask` instancia um `CallbackHandler()` do [Langfuse](https://langfuse.com/docs) para aquela requisição, enviando ao dashboard o trace completo (entradas, saídas, chamadas de ferramenta e tempos de inferência). As credenciais e a região são lidas do `.env` (`LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASE_URL`). O `collection_name` é injetado na configuração de runtime do [LangGraph](https://langchain-ai.github.io/langgraph/) — e não como tag do Langfuse.


## 🚀 Como Executar Localmente

### Pré-requisitos
1.  **[Docker](https://docs.docker.com/)**: Necessário para rodar o [Qdrant](https://qdrant.tech/documentation/) local.
2.  **[uv](https://docs.astral.sh/uv/)** (ou pip): Gerenciador de dependências python moderno.
3.  **Ambiente configurado**: Copie `.env.example` para `.env` e preencha as chaves. (OpenAI API e, opcionalmente, [Langfuse](https://langfuse.com/docs))
    ```bash
    cp .env.example .env
    ```

### Passos:

1.  **Instalar dependências (UV):**
    ```bash
    uv sync
    ```

2.  **Subir Qdrant + API de uma vez (atalho recomendado):**
    ```bash
    make dev
    ```
    O `make dev` garante o Docker/Qdrant no ar e sobe a API em `http://localhost:8000` (com auto-reload). Veja `make help` para os demais atalhos (`make down`, `make logs`).

    > Preferindo o modo manual: `docker compose up -d` (Qdrant) e depois `uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload` (API).

3.  **Testar via UI Própria!**
    *   Abra o `index.html` (duplo-clique) no navegador (Chrome/Edge).
    *   No painel esquerdo: crie uma **base de conhecimento** (ex.: `base_estudo`) e envie seus PDFs ou TXTs.
    *   No painel direito: selecione a base no menu **"Buscar na base"** e converse com o agente em tempo real!
