# Quick Gemini API check. Use Python 3.10+ (e.g. Homebrew python3.11) to avoid
# google-api-core / urllib3 noise on Apple’s system Python 3.9.
#   python3.11 -m pip install -U google-genai
#   export GEMINI_API_KEY='...'
#   python3.11 test.py

import os
import sys

from google import genai

if sys.version_info < (3, 10):
    print(
        "Tip: run with Python 3.10+ (e.g. python3.11 test.py) to avoid Google SDK version warnings.",
        file=sys.stderr,
    )

if not os.environ.get("GEMINI_API_KEY"):
    raise SystemExit(
        "Set GEMINI_API_KEY in your environment, e.g. export GEMINI_API_KEY='your-key'"
    )

client = genai.Client()
response = client.models.generate_content(
    model="gemini-2.0-flash",
    contents="Say hi in one word.",
)
print(response.text)
