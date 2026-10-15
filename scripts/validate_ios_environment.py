#!/usr/bin/env python3
"""Fail an Xcode build if Dart configuration and native app identity differ."""
import base64
import os
import plistlib
from pathlib import Path


def validate(env):
    defines = dict(
        base64.b64decode(value).decode().split("=", 1)
        for value in env.get("DART_DEFINES", "").split(",") if value
    )
    stage = defines.get("BLAB_ENV")
    if stage not in ("production", "staging"):
        raise ValueError("Build with env/production.json or env/staging.json")
    test = stage == "staging"
    expected = "blab.nastia.ez.test" if test else "blab.nastia.ez"
    if env.get("PRODUCT_BUNDLE_IDENTIFIER") != expected:
        raise ValueError("Native identity differs from Dart environment; run prepare_ios.py")
    if defines.get("BLAB_APP_CHANNEL", "public") != ("test" if test else "public"):
        raise ValueError("App channel differs from native identity")
    expected_ref = "tpfksdljkfnenjfdbane" if test else "bhzcexhebjszwyqvcsxs"
    if defines.get("SUPABASE_PROJECT_REF") != expected_ref:
        raise ValueError("Backend project differs from native identity")
    config = plistlib.loads((Path(env["SRCROOT"]) / "Runner/GoogleService-Info.plist").read_bytes())
    if config["BUNDLE_ID"] != expected or config["PROJECT_ID"] != defines.get("FIREBASE_PROJECT_ID"):
        raise ValueError("Firebase project differs from native identity")


if __name__ == "__main__":
    try:
        validate(os.environ)
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit(f"error: Blab iOS environment: {error}")
    print("Blab iOS environment verified")
