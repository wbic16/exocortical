# see: https://docs.llamaindex.ai/en/stable/module_guides/models/embeddings/#modules
# see: https://docs.llamaindex.ai/en/stable/getting_started/starter_example/
# see: https://docs.llamaindex.ai/en/stable/getting_started/starter_example_local/

# dependencies
# pip install llama-index openai tf-keras llama-index-embeddings-huggingface 
# pip install -U openai-whisper

from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.llms.ollama import Ollama

import sys

Settings.embed_model = HuggingFaceEmbedding(
    model_name="BAAI/bge-small-en-v1.5"
)
if len(sys.argv) >= 3:
    user_directory = sys.argv[1]
    user_model = sys.argv[2]
    user_query = sys.argv[3]
    Settings.llm = Ollama(model=user_model, request_timeout=360.0)
    documents = SimpleDirectoryReader(user_directory).load_data()
    index = VectorStoreIndex.from_documents(documents)
    query_engine = index.as_query_engine()
    response = query_engine.query(user_query)
    print(response)
else:
    print("Usage: rag.py <path> <model> <query>")
    print(len(sys.argv))

