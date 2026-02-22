"""
Tests for log context utilities and PII masking.
"""

import pytest

from app.utils.log_context import (
    mask_sensitive_value,
    mask_pii_in_text,
    safe_log_dict,
)


class TestMaskSensitiveValue:
    """Tests for mask_sensitive_value function."""
    
    def test_masks_short_string(self):
        """Test masking of short strings."""
        result = mask_sensitive_value("short", visible_chars=2)
        assert result == "***rt"
    
    def test_masks_long_string(self):
        """Test masking of long strings."""
        result = mask_sensitive_value("secret_password_123", visible_chars=4)
        assert result == "***************_123"
    
    def test_completely_masks_very_short_string(self):
        """Test that very short strings are completely masked."""
        result = mask_sensitive_value("pwd", visible_chars=4)
        assert result == "***"
        assert "pwd" not in result
    
    def test_masks_dict_values(self):
        """Test masking of dictionary values."""
        data = {
            "username": "john",
            "password": "secret123"
        }
        result = mask_sensitive_value(data, visible_chars=3)
        
        assert result["username"] == "*ohn"
        assert result["password"] == "******123"
    
    def test_masks_nested_dict(self):
        """Test masking of nested dictionaries."""
        data = {
            "user": {
                "name": "john",
                "credentials": {
                    "password": "secret"
                }
            }
        }
        result = mask_sensitive_value(data, visible_chars=2)
        
        assert result["user"]["name"] == "**hn"
        assert result["user"]["credentials"]["password"] == "****et"
    
    def test_masks_list_items(self):
        """Test masking of list items."""
        data = ["token1", "token2", "token3"]
        result = mask_sensitive_value(data, visible_chars=1)
        
        assert all("*" in item for item in result)


class TestMaskPIIInText:
    """Tests for mask_pii_in_text function."""
    
    def test_masks_email_addresses(self):
        """Test that email addresses are masked."""
        text = "Contact me at john.doe@example.com for details"
        result = mask_pii_in_text(text)
        
        assert "john.doe@example.com" not in result
        assert "example.com" in result  # Domain should be visible
        assert "***@example.com" in result
    
    def test_masks_phone_numbers(self):
        """Test that phone numbers are masked."""
        text = "Call me at 555-123-4567 or 555.987.6543"
        result = mask_pii_in_text(text)
        
        assert "555-123-4567" not in result
        assert "***-***-4567" in result
    
    def test_masks_ssn(self):
        """Test that SSN is completely masked."""
        text = "SSN: 123-45-6789"
        result = mask_pii_in_text(text)
        
        assert "123-45-6789" not in result
        assert "***-**-****" in result
    
    def test_masks_credit_card_numbers(self):
        """Test that credit card numbers are masked."""
        text = "Card: 1234-5678-9012-3456"
        result = mask_pii_in_text(text)
        
        assert "1234-5678-9012-3456" not in result
        assert "3456" in result  # Last 4 digits visible
    
    def test_masks_multiple_pii_types(self):
        """Test that multiple PII types are masked in same text."""
        text = "Email: john@example.com, Phone: 555-123-4567, SSN: 123-45-6789"
        result = mask_pii_in_text(text)
        
        assert "john@example.com" not in result
        assert "555-123-4567" not in result
        assert "123-45-6789" not in result
    
    def test_preserves_non_pii_content(self):
        """Test that non-PII content is preserved."""
        text = "Hello world! This is a test with no PII."
        result = mask_pii_in_text(text)
        
        assert result == text


class TestSafeLogDict:
    """Tests for safe_log_dict function."""
    
    def test_masks_password_fields(self):
        """Test that password fields are masked."""
        data = {
            "username": "john",
            "password": "secret123",
            "email": "john@example.com"
        }
        result = safe_log_dict(data)
        
        assert result["username"] == "john"
        assert result["password"] == "***MASKED***"
        assert result["email"] == "john@example.com"
    
    def test_masks_token_fields(self):
        """Test that token fields are masked."""
        data = {
            "user_id": "123",
            "access_token": "jwt_token_here",
            "refresh_token": "refresh_token_here"
        }
        result = safe_log_dict(data)
        
        assert result["user_id"] == "123"
        assert result["access_token"] == "***MASKED***"
        assert result["refresh_token"] == "***MASKED***"
    
    def test_masks_api_key_fields(self):
        """Test that API key fields are masked."""
        data = {
            "service": "spotify",
            "api_key": "secret_key_123",
            "apikey": "another_key"
        }
        result = safe_log_dict(data)
        
        assert result["service"] == "spotify"
        assert result["api_key"] == "***MASKED***"
        assert result["apikey"] == "***MASKED***"
    
    def test_masks_nested_sensitive_fields(self):
        """Test that sensitive fields in nested dicts are masked."""
        data = {
            "user": {
                "name": "john",
                "credentials": {
                    "password": "secret",
                    "api_key": "key123"
                }
            }
        }
        result = safe_log_dict(data)
        
        assert result["user"]["name"] == "john"
        assert result["user"]["credentials"]["password"] == "***MASKED***"
        assert result["user"]["credentials"]["api_key"] == "***MASKED***"
    
    def test_case_insensitive_masking(self):
        """Test that masking is case-insensitive."""
        data = {
            "Password": "secret",
            "PASSWORD": "secret2",
            "PaSsWoRd": "secret3"
        }
        result = safe_log_dict(data)
        
        assert all(v == "***MASKED***" for v in result.values())
    
    def test_custom_sensitive_keys(self):
        """Test that custom sensitive keys can be provided."""
        data = {
            "username": "john",
            "custom_secret": "sensitive_data"
        }
        result = safe_log_dict(data, sensitive_keys={"custom_secret"})
        
        assert result["username"] == "john"
        assert result["custom_secret"] == "***MASKED***"

