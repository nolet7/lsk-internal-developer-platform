"""Read-only Microsoft Azure OpenAI access review using Entra workload identity."""
from __future__ import annotations
import os
from fastapi import HTTPException

def generate_advice(prompt: str) -> str:
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT")
    if not endpoint or not deployment:
        raise HTTPException(503, "Azure OpenAI advisory is not configured")
    try:
        from azure.identity import DefaultAzureCredential, get_bearer_token_provider
        from openai import AzureOpenAI
        token_provider = get_bearer_token_provider(
            DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
        )
        client = AzureOpenAI(
            azure_endpoint=endpoint,
            azure_ad_token_provider=token_provider,
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21"),
        )
        response = client.chat.completions.create(
            model=deployment, max_tokens=350, temperature=0.1,
            messages=[
                {"role": "system", "content": "Read-only IAM security guidance. No approvals or tool execution."},
                {"role": "user", "content": prompt[:2200]},
            ],
        )
        text = (response.choices[0].message.content or "").strip()
        if not text:
            raise HTTPException(502, "Azure OpenAI returned no advice")
        return text[:1500]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(502, "Azure OpenAI advisory unavailable") from exc


def explain_template(template_key: str, description: str) -> str:
    prompt = (
        "LSK internal developer platform read-only advisor. Explain the approved "
        "golden path in 3 concise sentences. Never deploy resources, approve access "
        "or suggest bypassing change control. Only trusted catalog metadata is sent. "
        f"Template: {template_key[:70]}. Description: {description[:500]}"
    )
    return generate_advice(prompt)
