"""从 configs.toml 驱动的配置文件部署脚本。

用法：python deploy.py <configs.toml> <repo_url> [--stage config]
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tomllib
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="部署配置文件到系统")
    parser.add_argument("toml_path", help="configs.toml 路径")
    parser.add_argument("repo_url", help="远程仓库基础 URL")
    parser.add_argument("--stage", default="config", help="筛选部署阶段（默认 config）")
    args = parser.parse_args()

    with open(args.toml_path, "rb") as f:
        data = tomllib.load(f)

    home = Path.home()
    count = 0

    for item in data.get("configs", []):
        if item.get("stage", "config") != args.stage:
            continue

        source = item["source"]
        target = item["target"]
        target_path = Path(target).expanduser()
        is_system = not target_path.is_relative_to(home)

        url = f"{args.repo_url}/files/{source}"
        result = subprocess.run(
            ["curl", "-Lf", url],
            capture_output=True,
            check=True,
        )
        content = result.stdout

        parent = target_path.parent
        if is_system:
            subprocess.run(["sudo", "mkdir", "-p", str(parent)], check=True)
            subprocess.run(
                ["sudo", "tee", str(target_path)],
                input=content,
                stdout=subprocess.DEVNULL,
                check=True,
            )
        else:
            parent.mkdir(parents=True, exist_ok=True)
            target_path.write_bytes(content)

        print(f"  ✓ {source} → {target}")
        count += 1

    print(f"部署完成：{count} 个文件")


if __name__ == "__main__":
    main()
