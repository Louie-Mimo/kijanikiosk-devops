#!/usr/bin/env python3

import argparse
import json
import sys


def main():
    parser = argparse.ArgumentParser(
        description="Calculate KijaniKiosk HTTP error rate from JSONL probe logs."
    )

    parser.add_argument(
        "log_file",
        help="JSONL file containing HTTP probe results",
    )

    parser.add_argument(
        "--threshold",
        type=float,
        default=5.0,
        help="Maximum acceptable error rate percentage (default: 5.0)",
    )

    args = parser.parse_args()

    total_requests = 0
    error_requests = 0

    try:
        with open(args.log_file, "r", encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                line = line.strip()

                if not line:
                    continue

                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    print(
                        f"ERROR: invalid JSON at line {line_number}: {exc}",
                        file=sys.stderr,
                    )
                    return 2

                status = record.get("status")

                if not isinstance(status, int):
                    print(
                        f"ERROR: line {line_number} has no integer HTTP status",
                        file=sys.stderr,
                    )
                    return 2

                total_requests += 1

                # 0 means the HTTP request could not be completed.
                # HTTP 5xx means the service returned a server-side error.
                if status == 0 or status >= 500:
                    error_requests += 1

    except FileNotFoundError:
        print(
            f"ERROR: log file not found: {args.log_file}",
            file=sys.stderr,
        )
        return 2

    if total_requests == 0:
        print("ERROR: no HTTP probe records found", file=sys.stderr)
        return 2

    error_rate = (error_requests / total_requests) * 100.0

    print("=== KIJANIKIOSK ERROR-RATE SUMMARY ===")
    print(f"TOTAL_REQUESTS={total_requests}")
    print(f"ERROR_REQUESTS={error_requests}")
    print(f"ERROR_RATE={error_rate:.2f}%")
    print(f"THRESHOLD={args.threshold:.2f}%")

    # Requirement is greater than 5%, not greater-than-or-equal.
    if error_rate > args.threshold:
        print("STATUS=ALERT")
        print(
            f"ALERT: {error_rate:.2f}% error rate exceeds "
            f"{args.threshold:.2f}% threshold."
        )
        return 1

    print("STATUS=HEALTHY")
    print(
        f"HEALTHY: {error_rate:.2f}% error rate is within "
        f"{args.threshold:.2f}% threshold."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
