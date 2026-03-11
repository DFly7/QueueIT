"""Custom application exceptions."""


class DuplicateJoinCodeError(Exception):
    """Raised when a session create fails because the join code already exists."""
