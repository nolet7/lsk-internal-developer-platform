"""Read-only Amazon Bedrock enterprise access review; never mutates IAM."""
from __future__ import annotations
import os
from fastapi import HTTPException

def generate_advice(prompt: str) -> str:
    model = os.getenv("LSK_BEDROCK_MODEL_ID")
    region = os.getenv("AWS_REGION")
    if not model or not region:
        raise HTTPException(503, "Regional Bedrock advisory not configured")
    try:
        import boto3
        client = boto3.client("bedrock-runtime", region_name=region)
        response = client.converse(
            modelId=model,
            messages=[{"role": "user", "content": [{"text": prompt[:2200]}]}],
            inferenceConfig={"maxTokens": 350, "temperature": 0.1},
        )
        parts = response.get("output", {}).get("message", {}).get("content", [])
        text = " ".join(part.get("text", "") for part in parts).strip()
        if not text:
            raise HTTPException(502, "Bedrock returned an empty advisory")
        return text[:1500]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(502, "Bedrock advisory unavailable") from exc


def explain_template(template_key: str, description: str) -> str:
    prompt = (
        "LSK internal developer platform read-only advisor. Explain the approved "
        "golden path in 3 concise sentences. Never deploy resources, approve access "
        "or suggest bypassing change control. Only trusted catalog metadata is sent. "
        f"Template: {template_key[:70]}. Description: {description[:500]}"
    )
    return generate_advice(prompt)
