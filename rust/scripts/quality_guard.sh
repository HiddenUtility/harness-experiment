#!/bin/bash
set -e

echo "Running Quality Guard..."

echo "--- Running cargo fmt --check ---"
cargo fmt --check

echo "--- Running cargo clippy ---"
cargo clippy -- -D warnings

echo "--- Running cargo test ---"
cargo test

echo "Quality Guard passed successfully!"
