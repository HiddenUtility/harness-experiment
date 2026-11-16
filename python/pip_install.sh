
python3.14 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip

pip install pydantic

pip install build
pip install ruff

pip install twisted 
pip install anyio
pip install pytest 
pip install pytest-aiohttp
pip install pytest-asyncio 
pip install pytest-trio 
pip install pytest-mock

pip freeze > requirements.txt


