import subprocess
import sys
import shutil

def run_command(command):
    print(f"Running: {' '.join(command)}")
    result = subprocess.run(command, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    return result.returncode

def main():
    print("--- Starting Quality Guard ---")
    
    # 1. Linting with Ruff
    print("\n[1/2] Running Ruff...")
    if shutil.which("ruff") is None:
        print("Warning: 'ruff' not found. Skipping linting (or install it).")
    else:
        ruff_code = run_command(["ruff", "check", "."])
        if ruff_code != 0:
            print("Error: Ruff linting failed.")
            sys.exit(1)
    
    # 2. Testing with Pytest
    print("\n[2/2] Running Pytest...")
    if shutil.which("pytest") is None and shutil.which("python3") is not None:
        # Try running via python module if pytest command not in path
        print("Attempting to run 'python3 -m pytest'...")
        pytest_code = run_command(["python3", "-m", "pytest"])
    elif shutil.which("pytest") is None:
        print("Error: 'pytest' not found. Please install it.")
        sys.exit(1)
    else:
        pytest_code = run_command(["pytest"])

    if pytest_code != 0:
        print("Error: Pytest tests failed.")
        sys.exit(1)
    
    print("\n--- Quality Guard PASSED ---")
    sys.exit(0)

if __name__ == "__main__":
    main()
