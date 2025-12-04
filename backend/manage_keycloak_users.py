#!/usr/bin/env python3
"""
Keycloak User Management Script
Removes all existing users and creates new test users
"""

import requests
import json
import time
from typing import List, Dict

KEYCLOAK_URL = "http://localhost:8080"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"
REALM_NAME = "colink"


class KeycloakUserManager:
    def __init__(self):
        self.base_url = KEYCLOAK_URL
        self.admin_token = None

    def get_admin_token(self) -> str:
        """Get admin access token"""
        print("🔑 Getting admin access token...")
        url = f"{self.base_url}/realms/master/protocol/openid-connect/token"
        data = {
            "client_id": "admin-cli",
            "username": ADMIN_USER,
            "password": ADMIN_PASS,
            "grant_type": "password"
        }

        response = requests.post(url, data=data)
        response.raise_for_status()
        token = response.json()["access_token"]
        print("✅ Admin token obtained\n")
        return token

    def get_all_users(self, realm_name: str) -> List[Dict]:
        """Get all users in the realm"""
        print(f"📋 Fetching all users from realm '{realm_name}'...")
        url = f"{self.base_url}/admin/realms/{realm_name}/users"
        headers = {
            "Authorization": f"Bearer {self.admin_token}",
            "Content-Type": "application/json"
        }

        response = requests.get(url, headers=headers)
        response.raise_for_status()
        users = response.json()
        print(f"✅ Found {len(users)} users\n")
        return users

    def delete_user_by_id(self, realm_name: str, user_id: str, username: str) -> bool:
        """Delete a user by ID"""
        url = f"{self.base_url}/admin/realms/{realm_name}/users/{user_id}"
        headers = {
            "Authorization": f"Bearer {self.admin_token}",
            "Content-Type": "application/json"
        }

        response = requests.delete(url, headers=headers)
        if response.status_code == 204:
            print(f"   ✅ Deleted user: {username}")
            return True
        else:
            print(f"   ❌ Failed to delete user {username}: {response.status_code}")
            return False

    def delete_all_users(self, realm_name: str) -> int:
        """Delete all users from the realm"""
        print(f"🗑️  Deleting all users from realm '{realm_name}'...")
        users = self.get_all_users(realm_name)
        
        if not users:
            print("   No users to delete\n")
            return 0

        deleted_count = 0
        for user in users:
            user_id = user.get('id')
            username = user.get('username', 'unknown')
            if self.delete_user_by_id(realm_name, user_id, username):
                deleted_count += 1
            time.sleep(0.2)  # Small delay between deletions

        print(f"\n✅ Deleted {deleted_count} users\n")
        return deleted_count

    def create_user(self, realm_name: str, username: str, email: str, 
                   password: str, first_name: str, last_name: str) -> bool:
        """Create a new user in the realm"""
        print(f"👤 Creating user '{username}'...")

        url = f"{self.base_url}/admin/realms/{realm_name}/users"
        headers = {
            "Authorization": f"Bearer {self.admin_token}",
            "Content-Type": "application/json"
        }

        user_config = {
            "username": username,
            "email": email,
            "emailVerified": True,
            "enabled": True,
            "firstName": first_name,
            "lastName": last_name,
            "requiredActions": [],
            "credentials": [{
                "type": "password",
                "value": password,
                "temporary": False
            }]
        }

        try:
            response = requests.post(url, headers=headers, json=user_config)
            if response.status_code == 201:
                print(f"   ✅ User '{username}' created successfully")
                return True
            else:
                print(f"   ❌ Failed to create user: {response.status_code}")
                print(f"   Response: {response.text}")
                return False
        except Exception as e:
            print(f"   ❌ Error creating user: {e}")
            return False

    def manage_users(self):
        """Main function to manage users"""
        print("=" * 70)
        print("  KEYCLOAK USER MANAGEMENT")
        print("=" * 70)
        print()

        # Get admin token
        try:
            self.admin_token = self.get_admin_token()
        except Exception as e:
            print(f"❌ Failed to get admin token: {e}")
            print("   Make sure Keycloak is running on http://localhost:8080")
            return False

        # Delete all existing users
        self.delete_all_users(REALM_NAME)

        # Create new users
        new_users = [
            {
                "username": "john",
                "email": "john@colink.dev",
                "password": "Test@123",
                "first_name": "John",
                "last_name": "Doe"
            },
            {
                "username": "sarah",
                "email": "sarah@colink.dev",
                "password": "Test@123",
                "first_name": "Sarah",
                "last_name": "Smith"
            },
            {
                "username": "mike",
                "email": "mike@colink.dev",
                "password": "Test@123",
                "first_name": "Mike",
                "last_name": "Johnson"
            },
            {
                "username": "emma",
                "email": "emma@colink.dev",
                "password": "Test@123",
                "first_name": "Emma",
                "last_name": "Williams"
            }
        ]

        print("👥 Creating new users...")
        print()
        created_count = 0
        for user_data in new_users:
            if self.create_user(
                REALM_NAME,
                user_data["username"],
                user_data["email"],
                user_data["password"],
                user_data["first_name"],
                user_data["last_name"]
            ):
                created_count += 1
            time.sleep(0.5)

        print()
        print("=" * 70)
        print("  ✅ USER MANAGEMENT COMPLETE")
        print("=" * 70)
        print()
        print(f"Realm: {REALM_NAME}")
        print(f"Users created: {created_count}/{len(new_users)}")
        print()
        print("New User Credentials:")
        print("-" * 70)
        for user_data in new_users:
            print(f"  👤 {user_data['first_name']} {user_data['last_name']}")
            print(f"     Username: {user_data['username']}")
            print(f"     Email:    {user_data['email']}")
            print(f"     Password: {user_data['password']}")
            print()
        print("-" * 70)
        print()
        print("Access Keycloak Admin Console:")
        print(f"  URL:  {KEYCLOAK_URL}/admin")
        print(f"  User: {ADMIN_USER}")
        print(f"  Pass: {ADMIN_PASS}")
        print("=" * 70)

        return True


def main():
    manager = KeycloakUserManager()
    success = manager.manage_users()
    return 0 if success else 1


if __name__ == "__main__":
    import sys
    sys.exit(main())
