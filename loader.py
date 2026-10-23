"""
BREAKOUT loader updater
Local version: 1.0

Checks version.txt in the GitHub repository. If a newer version is available,
downloads loader.py into an "updates" folder for review.

For safety, this script does NOT automatically execute downloaded code or
overwrite the currently running script. Review the downloaded file before
replacing your local loader.py.
"""

from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

VERSION = "1.0"

REPOSITORY = "https://raw.githubusercontent.com/g5ddv1fdg5f/BREAKOUT/main"
VERSION_URL = f"{REPOSITORY}/version.txt"
LOADER_URL = f"{REPOSITORY}/loader.py"
TIMEOUT_SECONDS = 15


def fetch_text(url: str) -> str:
    request = Request(url, headers={"User-Agent": "BREAKOUT-Loader-Updater"})
    with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return response.read(4096).decode("utf-8-sig").strip()


def download_file(url: str, destination: Path) -> None:
    request = Request(url, headers={"User-Agent": "BREAKOUT-Loader-Updater"})
    with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        data = response.read(2 * 1024 * 1024 + 1)

    if len(data) > 2 * 1024 * 1024:
        raise ValueError("Le fichier distant dépasse la limite de 2 Mio.")

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


def version_tuple(value: str) -> tuple[int, ...]:
    parts = value.strip().split(".")
    if not parts or any(not part.isdigit() for part in parts):
        raise ValueError(f"Format de version invalide : {value!r}")
    return tuple(int(part) for part in parts)


def check_for_update() -> None:
    print(f"Version locale : {VERSION}")
    try:
        remote_version = fetch_text(VERSION_URL)
        print(f"Version GitHub : {remote_version}")

        if version_tuple(remote_version) <= version_tuple(VERSION):
            print("Aucune mise à jour disponible.")
            return

        destination = Path(__file__).resolve().parent / "updates" / "loader.py"
        download_file(LOADER_URL, destination)
        print(f"Une mise à jour ({remote_version}) a été téléchargée ici :")
        print(destination)
        print("Vérifie le fichier avant de remplacer ton loader.py actuel.")

    except (HTTPError, URLError, TimeoutError, OSError, UnicodeError, ValueError) as exc:
        print(f"Impossible de vérifier/télécharger la mise à jour : {exc}")


if __name__ == "__main__":
    check_for_update()
