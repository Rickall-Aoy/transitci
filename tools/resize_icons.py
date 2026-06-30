from PIL import Image
from pathlib import Path
import shutil

ICON_DIR = Path('assets/icons')
BACKUP_DIR = ICON_DIR / '_backup_originals'
TARGET_SIZE = (64, 64)

BACKUP_DIR.mkdir(parents=True, exist_ok=True)

for p in ICON_DIR.iterdir():
    if p.is_file() and p.suffix.lower() in ('.jpg', '.jpeg', '.png') and p.name != '_backup_originals':
        dest = BACKUP_DIR / p.name
        try:
            # backup original if not already backed up
            if not dest.exists():
                shutil.copy2(p, dest)

            img = Image.open(p)
            img.thumbnail(TARGET_SIZE, Image.LANCZOS)
            img.save(p, optimize=True, quality=85)
            print(f'Resized {p.name} -> {img.size}')
        except Exception as e:
            print(f'ERROR {p.name}: {e}')
