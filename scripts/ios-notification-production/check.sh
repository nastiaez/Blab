#!/bin/sh
# Lightweight checks only: no Flutter/Xcode archive, signing or device mutation.
set -eu
cd "$(dirname "$0")/../.."
xcrun swiftc -typecheck -application-extension  -target arm64-apple-ios15.0-simulator  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"  ios/NotificationShared/NotificationAccount.swift  ios/BlabNotificationContent/NotificationDisplay.swift  ios/Runner/BlabCommunication.swift  ios/BlabNotificationService/NotificationService.swift  ios/BlabNotificationContent/NotificationViewController.swift
binary="$(mktemp -t blab-notification-policy)"
trap 'rm -f "$binary"' EXIT
swiftc ios/NotificationShared/NotificationAccount.swift  scripts/ios-notification-production/main.swift -o "$binary"
"$binary"
