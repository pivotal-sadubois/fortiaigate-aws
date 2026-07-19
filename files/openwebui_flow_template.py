"""
title: FortiAIGate
author: Adrian / Sacha
version: 0.3.0
license: MIT
description: Secure OpenAI-compatible Pipe for FortiAIGate with native tool-calling support
"""

import json
import urllib3
from typing import Any, Dict, Generator, Union

import requests
from pydantic import BaseModel, Field


class Pipe:
    class Valves(BaseModel):
        FORTIAIGATE_URL: str = Field(
            default=(
                "https://core.fortiaigate.svc.cluster.local:8080/"
                "v1/openwebui/v1/chat/completions"
            ),
            description="FortiAIGate OpenAI-compatible chat-completions endpoint",
        )

        API_KEY: str = Field(
            default="<API_KEY>",
            description="FortiAIGate API token",
        )

        MODEL_ID: str = Field(
            default="faig-default",
            description="FortiAIGate model ID",
        )

        VERIFY_SSL: bool = Field(
            default=False,
            description="Verify FortiAIGate TLS certificate",
        )

        TIMEOUT: int = Field(
            default=120,
            description="Request timeout in seconds",
        )

        DEBUG: bool = Field(
            default=False,
            description="Return additional diagnostic information on errors",
        )

    def __init__(self):
        self.valves = self.Valves()

        urllib3.disable_warnings(
            urllib3.exceptions.InsecureRequestWarning
        )

    def pipes(self):
        return [
            {
                "id": "fortiaigate-default",
                "name": "FortiAIGate Default Model",
            }
        ]

    def pipe(
        self,
        body: dict,
        __user__: dict = None,
    ) -> Union[dict, str, Generator]:

        if not self.valves.API_KEY:
            return {
                "error": {
                    "message": (
                        "FortiAIGate API key is not configured. "
                        "Set API_KEY in the Function valves."
                    ),
                    "type": "configuration_error",
                }
            }

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.valves.API_KEY}",
        }

        #
        # Preserve the OpenAI-compatible request fields that FortiAIGate
        # needs, including native tools.
        #
        payload: Dict[str, Any] = {
            "model": self.valves.MODEL_ID,
            "messages": body.get("messages", []),
        }

        forwarded_fields = [
            "tools",
            "tool_choice",
            "parallel_tool_calls",
            "temperature",
            "top_p",
            "max_tokens",
            "max_completion_tokens",
            "stop",
            "seed",
            "frequency_penalty",
            "presence_penalty",
            "response_format",
            "stream_options",
            "user",
        ]

        for field in forwarded_fields:
            if field in body and body[field] is not None:
                payload[field] = body[field]

        stream = bool(body.get("stream", False))
        payload["stream"] = stream

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
                return {
                    "error": {
                        "message": "FortiAIGate authentication failed.",
                        "type": "authentication_error",
                        "code": 401,
                    }
                }

            if response.status_code == 403:
                return {
                    "error": {
                        "message": (
                            "FortiAIGate access denied. Check the API token, "
                            "network allowlist and AI Flow configuration."
                        ),
                        "type": "authorization_error",
                        "code": 403,
                    }
                }

            if response.status_code != 200:
                return {
                    "error": {
                        "message": response.text[:2000],
                        "type": "fortiaigate_error",
                        "code": response.status_code,
                    }
                }

            if stream:
                return self._stream_response(response)

            #
            # Important: return the complete OpenAI-compatible response.
            # Do not return only message.content because that drops tool_calls.
            #
            return response.json()

        except requests.exceptions.SSLError as exc:
            return {
                "error": {
                    "message": f"FortiAIGate TLS error: {exc}",
                    "type": "ssl_error",
                }
            }

        except requests.exceptions.ConnectionError as exc:
            return {
                "error": {
                    "message": f"Cannot reach FortiAIGate: {exc}",
                    "type": "connection_error",
                }
            }

        except requests.exceptions.Timeout:
            return {
                "error": {
                    "message": (
                        "FortiAIGate did not respond within "
                        f"{self.valves.TIMEOUT} seconds."
                    ),
                    "type": "timeout_error",
                }
            }

        except ValueError as exc:
            return {
                "error": {
                    "message": f"Invalid JSON response from FortiAIGate: {exc}",
                    "type": "response_error",
                }
            }

        except Exception as exc:
            return {
                "error": {
                    "message": str(exc),
                    "type": "pipe_error",
                }
            }

    def _stream_response(
        self,
        response: requests.Response,
    ) -> Generator[str, None, None]:

        for line in response.iter_lines(decode_unicode=True):
            if not line:
                continue

            if not line.startswith("data:"):
                continue

            data = line[5:].strip()

            if data == "[DONE]":
                break

            #
            # Forward the complete SSE chunk unchanged.
            # This preserves delta.tool_calls as well as delta.content.
            #
            yield f"data: {data}\n\n"

        yield "data: [DONE]\n\n"
