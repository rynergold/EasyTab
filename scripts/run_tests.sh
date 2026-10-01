#!/bin/bash
set -e

echo "🧪 Building and Running EasyTab Unit Tests..."
swiftc \
    Sources/EasyTab/Core/Models/WindowItem.swift \
    Sources/EasyTab/Core/StateMachine/SwitcherEngine.swift \
    Tests/EasyTabTests/TestRunner.swift \
    -o /tmp/easytab_tests

/tmp/easytab_tests
rm -f /tmp/easytab_tests
