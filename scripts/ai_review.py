import os
from openai import OpenAI

try:
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

repo = "https://github.com/etalli/262_KeyLens"

    prompt = """
Review this GitHub repository and propose improvements.

{repo}

Return 3 GitHub issue ideas with short descriptions.
"""

    response = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt
    )

    print(response.output_text)

except Exception as e:
    print("AI review failed:")
    print(str(e))