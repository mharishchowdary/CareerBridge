import hashlib
import os
import base64
import hmac  # Add this import

def hash_password(password: str) -> tuple[str, str]:
    """
    Hash a password using SHA-256 with a random salt.
    Returns the salt and hashed password as a tuple.
    """
    # Generate a random salt
    salt = os.urandom(32)
    
    # Combine password and salt, then hash
    salted_password = password.encode() + salt
    hashed_password = hashlib.sha256(salted_password).digest()
    
    # Convert binary values to storable strings
    salt_str = base64.b64encode(salt).decode('utf-8')
    hash_str = base64.b64encode(hashed_password).decode('utf-8')
    
    return salt_str, hash_str

def verify_password(password: str, stored_salt: str, stored_hash: str) -> bool:
    """
    Verify a password against its stored hash and salt.
    """
    # Decode the stored salt and hash from base64
    salt = base64.b64decode(stored_salt.encode('utf-8'))
    stored_hash_bytes = base64.b64decode(stored_hash.encode('utf-8'))
    
    # Hash the provided password with the stored salt
    salted_password = password.encode() + salt
    hashed_password = hashlib.sha256(salted_password).digest()
    
    # Compare the hashes using a constant-time comparison
    return hmac.compare_digest(hashed_password, stored_hash_bytes)