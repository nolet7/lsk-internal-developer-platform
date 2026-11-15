"""Optional Gemini-based catalog guidance; never performs provisioning or approval."""
from __future__ import annotations

import os

from fastapi import HTTPException


def explain_template(template_key: str, description: str) -> str:
    """Explain a catalog choice using Vertex AI. Input is catalog-owned text only."""
    project = os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("GOOGLE_CLOUD_LOCATION")
    model = os.getenv("GOOGLE_GENAI_MODEL")
    if not all([project, location, model]):
        raise HTTPException(503, "Vertex AI advisory not configured")

    from google import genai

    prompt = (
        "Explain the following approved internal platform template in 3 concise sentences. "
        "Do not suggest bypassing authentication, policy review, or human approvals. "
        "This is informational only, not an access or deployment decision.\n"
        f"Catalog entry: {template_key}\nDescription: {description}"
    )
    try:
        with genai.Client(vertexai=True, project=project, location=location) as client:
            response = client.models.generate_content(model=model, contents=prompt)
        if not response.text:
            raise HTTPException(502, "Model returned no advice")
        return response.text[:1600]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(502, "AI advisory temporarily unavailable") from exc
