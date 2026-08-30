"""Règles d’inscription / reset. Le login des anciens hash n’est pas concerné."""

import re

MIN_LENGTH = 8
MAX_LENGTH = 72

PASSWORD_RULE_MESSAGE = (
    "Le mot de passe doit contenir au moins 8 caractères, une minuscule, "
    "une MAJUSCULE, un chiffre et un caractère spécial."
)

_LOWER = re.compile(r"[a-z]")
_UPPER = re.compile(r"[A-Z]")
_DIGIT = re.compile(r"\d")
_SPECIAL = re.compile(r"[^A-Za-z0-9]")


def password_strength_error(password: str) -> str | None:
    if len(password) < MIN_LENGTH or len(password) > MAX_LENGTH:
        return PASSWORD_RULE_MESSAGE
    if _LOWER.search(password) is None:
        return PASSWORD_RULE_MESSAGE
    if _UPPER.search(password) is None:
        return PASSWORD_RULE_MESSAGE
    if _DIGIT.search(password) is None:
        return PASSWORD_RULE_MESSAGE
    if _SPECIAL.search(password) is None:
        return PASSWORD_RULE_MESSAGE
    return None


def require_strong_password(password: str) -> str:
    error = password_strength_error(password)
    if error is not None:
        raise ValueError(error)
    return password
