"""Business logic. Services never import FastAPI: they raise domain errors and
the transport layer maps those onto HTTP status codes.
"""
