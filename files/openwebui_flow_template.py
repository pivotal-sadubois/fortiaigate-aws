"""
title: FortiAIGate
author: Adrian
version: 0.2.0
license: MIT
description: Secure Pipe function to route Open WebUI requests through FortiAIGate AI Security Gateway with HTTPS and API key authentication
"""
 
import requests
import json
import urllib3
from typing import Union, Generator
from pydantic import BaseModel, Field
 
 
class Pipe:
    class Valves(BaseModel):
        FORTIAIGATE_URL: str = Field(
            default="https://core.fortiaigate.svc.cluster.local:8080/v1/openwebui/v1/chat/completions",
            description="FortiAIGate chat completions endpoint URL (use https:// for encrypted communication)",
        )
        API_KEY: str = Field(
            default="<API_KEY>",
            description="FortiAIGate API Token (generate in FortiAIGate Admin GUI → System → API Tokens)",
        )
        MODEL_ID: str = Field(
            default="global.anthropic.claude-sonnet-4-6",
            description="Model ID configured in FortiAIGate AI Flow",
        )
        VERIFY_SSL: bool = Field(
            default=False,
            description="Verify SSL certificate (set False for self-signed FortiAIGate certs, True if using a trusted CA)",
        )
        TIMEOUT: int = Field(
            default=120,
            description="Request timeout in seconds",
        )
 
    def __init__(self):
        self.valves = self.Valves()
        # Suppress InsecureRequestWarning when using self-signed certificates
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
 
    def pipes(self):
        return [
            {
                "id": "fortiaigate-claude-sonnet",
                "name": "FortiAIGate Claude Sonnet",
            }
        ]
 
    def pipe(self, body: dict, __user__: dict = None) -> Union[str, Generator]:
        # Validate API key is configured
        if not self.valves.API_KEY:
            return (
                "⚠️ FortiAIGate API key not configured. "
                "Go to Functions → FortiAIGate → Valves → set API_KEY."
            )
 
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.valves.API_KEY}",
        }
 
        # Build clean payload — exactly like our working curl command
        payload = {
            "model": self.valves.MODEL_ID,
            "messages": body.get("messages", []),
        }
 
        stream = body.get("stream", False)
        if stream:
            payload["stream"] = True
 
        try:
            response = requests.post(
                self.valves.FORTIAIGATE_URL,
                headers=headers,
                json=payload,
                stream=stream,
                timeout=self.valves.TIMEOUT,
                verify=self.valves.VERIFY_SSL,
            )
 
            if response.status_code == 401:
                return "⚠️ Authentication failed (401). Check your API key in Valves settings."
            elif response.status_code == 403:
                return (
                    "⚠️ Access denied (403). Possible causes: "
                    "invalid API key, network allowlist, or AI Flow not configured."
                )
            elif response.status_code != 200:
                return (
                    f"FortiAIGate error {response.status_code}: {response.text[:500]}"
                )
 
            if stream:
                return self._stream_response(response)
            else:
                result = response.json()
                if "choices" in result and len(result["choices"]) > 0:
                    return result["choices"][0]["message"]["content"]
                return json.dumps(result)
 
        except requests.exceptions.SSLError as e:
            return (
                f"⚠️ SSL error: {str(e)[:200]}. "
                "If using self-signed certs, set VERIFY_SSL=False in Valves."
            )
        except requests.exceptions.ConnectionError:
            return (
                "⚠️ Connection error: Cannot reach FortiAIGate. "
                "Check the URL in Valves settings and ensure the core service is running."
            )
        except requests.exceptions.Timeout:
            return f"⚠️ Timeout: FortiAIGate did not respond within {self.valves.TIMEOUT} seconds."
        except Exception as e:
            return f"Error: {str(e)}"
 
    def _stream_response(self, response) -> Generator:
        for line in response.iter_lines():
            if line:
                decoded = line.decode("utf-8")
                if decoded.startswith("data: "):
                    data = decoded[6:]
                    if data.strip() == "[DONE]":
                        return
                    try:
                        chunk = json.loads(data)
                        if "choices" in chunk and len(chunk["choices"]) > 0:
                            delta = chunk["choices"][0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                yield content
                    except json.JSONDecodeError:
                        continue
