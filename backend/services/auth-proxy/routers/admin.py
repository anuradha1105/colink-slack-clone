"""Admin routes for user management.

This module provides endpoints for admin users to manage other users in the system.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from shared.database import User, UserRole, UserStatus, get_db
from ..services.keycloak import KeycloakService
import structlog

logger = structlog.get_logger()

router = APIRouter(prefix="/admin", tags=["admin"])
security = HTTPBearer()


# ============================================================================
# Helper Functions
# ============================================================================


async def verify_admin_user(token: str, db: AsyncSession) -> User:
    """Verify that the requesting user is an admin.

    Args:
        token: JWT access token
        db: Database session

    Returns:
        User: The admin user object

    Raises:
        HTTPException: If user is not authenticated or not an admin
    """
    try:
        # Validate token with Keycloak
        keycloak = KeycloakService()
        user_info = await keycloak.get_user_info(token)

        # Get user from database
        stmt = select(User).where(User.keycloak_id == user_info["sub"])
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        # Check if user is admin
        if user.role != UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Admin privileges required.",
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to verify admin user: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
        )


# ============================================================================
# Response Models
# ============================================================================


from pydantic import BaseModel
from datetime import datetime


class UserListItem(BaseModel):
    """User information for list view."""

    id: str
    keycloak_id: str
    username: str
    email: str
    display_name: str | None
    role: str
    status: str
    created_at: datetime
    last_seen_at: datetime | None


class UsersListResponse(BaseModel):
    """Response model for users list."""

    users: List[UserListItem]
    total: int


# ============================================================================
# Endpoints
# ============================================================================


@router.get("/users", response_model=UsersListResponse)
async def list_all_users(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(security),
):
    """Get list of all users in the system.

    This endpoint requires admin privileges.
    """
    try:
        # Verify admin user
        admin_user = await verify_admin_user(token.credentials, db)

        logger.info(f"Admin {admin_user.username} requesting user list")

        # Get all users
        stmt = select(User).where(User.status != UserStatus.DELETED).order_by(User.created_at.desc())
        result = await db.execute(stmt)
        users = result.scalars().all()

        return UsersListResponse(
            users=[
                UserListItem(
                    id=str(user.id),
                    keycloak_id=user.keycloak_id,
                    username=user.username,
                    email=user.email,
                    display_name=user.display_name,
                    role=user.role.value,
                    status=user.status.value,
                    created_at=user.created_at,
                    last_seen_at=user.last_seen_at,
                )
                for user in users
            ],
            total=len(users),
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to list users: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve users",
        )


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    token: str = Depends(security),
):
    """Delete a user from the system.

    This endpoint requires admin privileges.
    """
    try:
        # Verify admin user
        admin_user = await verify_admin_user(token.credentials, db)

        # Prevent admin from deleting themselves
        if str(admin_user.id) == user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete your own account",
            )

        # Get user to delete
        stmt = select(User).where(User.id == user_id)
        result = await db.execute(stmt)
        user_to_delete = result.scalar_one_or_none()

        if not user_to_delete:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        logger.info(f"Admin {admin_user.username} deleting user {user_to_delete.username}")

        # Mark user as deleted (soft delete)
        user_to_delete.status = UserStatus.DELETED
        await db.commit()

        # Also delete user from Keycloak
        try:
            keycloak = KeycloakService()
            await keycloak.delete_user(user_to_delete.keycloak_id)
        except Exception as e:
            logger.warning(f"Failed to delete user from Keycloak: {e}")
            # Continue even if Keycloak deletion fails

        return {"message": f"User {user_to_delete.username} deleted successfully"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete user: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete user",
        )
