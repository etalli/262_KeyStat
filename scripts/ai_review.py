import os
import subprocess
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

files = subprocess.check_output(
    ["git", "ls-files"], text=True
)

prompt = f"""
You are reviewing a GitHub repository.

Repository URL:
https://github.com/etalli/262_KeyLens

Project file list:

{files}

Suggest 3 useful GitHub issues to improve this project.
"""

response = client.responses.create(
    model="gpt-4.1-mini",
    input=prompt
)

print(response.output_text)