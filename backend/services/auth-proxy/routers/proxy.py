"""Proxy router for forwarding requests to backend services."""

import logging
from typing import Optional

import httpx
from fastapi import APIRouter, Request, Response

logger = logging.getLogger(__name__)

router = APIRouter()

# Service URLs (internal Docker network)
SERVICE_URLS = {
    "channels": "http://channel:8003",
    "messages": "http://message:8002",
    "threads": "http://threads:8005",
    "reactions": "http://reactions:8006",
    "files": "http://files:8007",
    "users": "http://auth-proxy:8001",  # Users are handled by auth-proxy itself
}


async def proxy_request(
    request: Request,
    target_url: str,
    path: str,
) -> Response:
    """Forward request to target service."""
    # Get the authorization header
    auth_header = request.headers.get("authorization", "")
    
    # Build headers to forward
    headers = {
        "authorization": auth_header,
        "content-type": request.headers.get("content-type", "application/json"),
        "accept": request.headers.get("accept", "application/json"),
    }
    
    # Get query params
    query_string = str(request.query_params) if request.query_params else ""
    
    # Build full URL
    full_url = f"{target_url}{path}"
    if query_string:
        full_url = f"{full_url}?{query_string}"
    
    logger.info(f"Proxying {request.method} to {full_url} with headers: {headers}")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Get body for non-GET requests
            body = None
            if request.method in ["POST", "PUT", "PATCH"]:
                body = await request.body()
            
            response = await client.request(
                method=request.method,
                url=full_url,
                headers=headers,
                content=body,
            )
            
            # Return the proxied response
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.headers.get("content-type"),
            )
    except httpx.TimeoutException:
        logger.error(f"Timeout proxying to {full_url}")
        return Response(
            content='{"detail": "Service timeout"}',
            status_code=504,
            media_type="application/json",
        )
    except Exception as e:
        logger.error(f"Error proxying to {full_url}: {e}")
        return Response(
            content=f'{{"detail": "Proxy error: {str(e)}"}}',
            status_code=502,
            media_type="application/json",
        )


# Channel routes - specific routes first, then catch-all
@router.api_route("/channels", methods=["GET", "POST"])
async def proxy_channels_root(request: Request):
    """Proxy channel root requests to channel service."""
    return await proxy_request(request, SERVICE_URLS["channels"], "/channels")


@router.api_route("/channels/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_channels(request: Request, path: str = ""):
    """Proxy channel requests to channel service."""
    target_path = f"/channels/{path}" if path else "/channels"
    return await proxy_request(request, SERVICE_URLS["channels"], target_path)


# Message routes - specific routes first, then catch-all
@router.api_route("/messages", methods=["GET", "POST"])
async def proxy_messages_root(request: Request):
    """Proxy message root requests to message service."""
    return await proxy_request(request, SERVICE_URLS["messages"], "/messages")


@router.api_route("/messages/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_messages(request: Request, path: str = ""):
    """Proxy message requests to message service."""
    target_path = f"/messages/{path}" if path else "/messages"
    return await proxy_request(request, SERVICE_URLS["messages"], target_path)


# Thread routes
@router.api_route("/threads/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_threads(request: Request, path: str = ""):
    """Proxy thread requests to threads service."""
    target_path = f"/threads/{path}" if path else "/threads"
    return await proxy_request(request, SERVICE_URLS["threads"], target_path)


# File routes
@router.api_route("/files/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_files(request: Request, path: str = ""):
    """Proxy file requests to files service."""
    target_path = f"/files/{path}" if path else "/files"
    return await proxy_request(request, SERVICE_URLS["files"], target_path)
