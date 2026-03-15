import os
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

prompt = """
Analyze this macOS keyboard analysis tool repository.

Focus on:
- typing ergonomics metrics
- keyboard layout analysis
- visualization improvements
- privacy-safe logging
- performance

Propose 3 concrete GitHub issues.
"""

response = client.responses.create(
    model="gpt-4.1-mini",
    input=prompt
)

with open("issue.txt","w") as f:
    f.write(response.output_text)
