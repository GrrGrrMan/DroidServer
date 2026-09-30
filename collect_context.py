import argparse
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Set, Tuple

# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================
# Set whether to check .gitignore in the script directory
USE_GITIGNORE: bool = False

# Set whether to check the additional exclusions file in the script directory
USE_EXCLUSIONS_FILE: bool = True

# Name of your custom exclusions file (uses exact .gitignore syntax)
# Will also check for '.contextignore' or 'additional_exclusions' if not found
EXCLUSIONS_FILENAME: str = "additional_exclusions.txt"

PROJECT_ROOT = Path(__file__).resolve().parent

# Common binary file extensions to skip without reading disk contents
COMMON_BINARY_EXTENSIONS: Set[str] = {
    '.pak', '.dll', '.exe', '.bin', '.dat', '.wasm', '.zip', '.tar', '.gz',
    '.7z', '.rar', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.bmp',
    '.pdf', '.mp3', '.mp4', '.wav', '.ogg', '.flac', '.avi', '.mov', '.mkv',
    '.ttf', '.otf', '.woff', '.woff2', '.eot', '.class', '.jar', '.pyc',
    '.pyd', '.so', '.dylib', '.o', '.obj', '.db', '.sqlite', '.sqlite3',
    '.iso', '.dmg', '.min.js', '.min.css', '.map'
}


class ExclusionFilter:
    """Parses and matches .gitignore-formatted rules."""

    def __init__(
        self,
        root_dir: Path,
        script_path: Path,
        use_gitignore: bool = USE_GITIGNORE,
        use_exclusions_file: bool = USE_EXCLUSIONS_FILE,
        custom_file_path: Optional[Path] = None
    ):
        self.root_dir = root_dir.resolve()
        self.script_path = script_path.resolve()
        self.rules: List[Tuple[bool, re.Pattern]] = []

        # Internal files that should always be ignored
        self.always_exclude_names: Set[str] = {
            '.git',
            self.script_path.name,
            '.gitignore',
            EXCLUSIONS_FILENAME,
            '.contextignore',
            'additional_exclusions',
            'additional_exclusions.txt',
        }

        # 1. Load .gitignore if enabled
        if use_gitignore:
            gitignore_file = self.root_dir / '.gitignore'
            if gitignore_file.is_file():
                count = self._load_ignore_file(gitignore_file)
                print(f"[INFO] Loaded {count} rule(s) from .gitignore")
            else:
                print("[INFO] No .gitignore file found in script directory.")

        # 2. Load custom exclusions file if enabled
        if use_exclusions_file:
            target_file = self._find_exclusions_file(custom_file_path)
            if target_file and target_file.is_file():
                count = self._load_ignore_file(target_file)
                print(f"[INFO] Loaded {count} rule(s) from {target_file.name}")
            elif custom_file_path:
                print(f"[WARN] Specified exclusions file not found: {custom_file_path}", file=sys.stderr)

    def _find_exclusions_file(self, custom_path: Optional[Path]) -> Optional[Path]:
        if custom_path:
            return custom_path

        candidates = [
            self.root_dir / EXCLUSIONS_FILENAME,
            self.root_dir / '.contextignore',
            self.root_dir / 'additional_exclusions.txt',
            self.root_dir / 'additional_exclusions',
        ]
        for candidate in candidates:
            if candidate.is_file():
                return candidate
        return None

    def _compile_pattern(self, raw_pattern: str) -> Optional[Tuple[bool, re.Pattern]]:
        p = raw_pattern.strip()
        # Skip empty lines and comment lines
        if not p or p.startswith('#'):
            return None

        # Check for negation rule (!)
        is_negated = p.startswith('!')
        if is_negated:
            p = p[1:]

        # Trailing slash means directory-only
        dir_only = p.endswith('/')
        if dir_only:
            p = p[:-1]

        # In gitignore: patterns starting with / or containing / are pinned to root
        pinned = p.startswith('/') or ('/' in p)
        p = p.lstrip('/')

        tokens: List[str] = []
        i = 0
        n = len(p)
        while i < n:
            if p[i:i + 3] == '**/':
                tokens.append('(?:.+/)?')
                i += 3
            elif p[i:i + 2] == '**':
                tokens.append('.*')
                i += 2
            elif p[i] == '*':
                tokens.append('[^/]*')
                i += 1
            elif p[i] == '?':
                tokens.append('[^/]')
                i += 1
            elif p[i] in r'.[{()+^$|':
                tokens.append('\\' + p[i])
                i += 1
            else:
                tokens.append(p[i])
                i += 1

        body = ''.join(tokens)
        suffix = '/.*' if dir_only else '(?:/.*)?'
        prefix = '^' if pinned else '(?:^|.*/)'

        regex = re.compile(f"{prefix}{body}{suffix}$")
        return is_negated, regex

    def _load_ignore_file(self, path: Path) -> int:
        count = 0
        try:
            lines = path.read_text(encoding='utf-8', errors='ignore').splitlines()
            for line in lines:
                rule = self._compile_pattern(line)
                if rule:
                    self.rules.append(rule)
                    count += 1
        except Exception as err:
            print(f"[WARN] Could not read {path.name}: {err}", file=sys.stderr)
        return count

    def is_ignored(self, path: Path, is_dir: bool) -> bool:
        if path.name in self.always_exclude_names:
            return True

        # Exclude secrets/environment files by default (unless .example)
        if path.name.startswith('.env') and not path.name.endswith('.example'):
            return True

        try:
            rel_path = path.resolve().relative_to(self.root_dir).as_posix()
        except ValueError:
            rel_path = path.name

        # Directories are appended with '/' to properly match dir_only rules
        test_path = rel_path + '/' if is_dir else rel_path

        ignored = False
        for is_negated, regex in self.rules:
            if regex.search(test_path):
                ignored = not is_negated
        return ignored


def is_binary_file(filepath: Path) -> bool:
    """Fast binary check by extension and null-byte header sniff."""
    if filepath.suffix.lower() in COMMON_BINARY_EXTENSIONS:
        return True
    try:
        with open(filepath, 'rb') as f:
            chunk = f.read(1024)
            if b'\x00' in chunk:
                return True
    except Exception:
        return True
    return False


def is_relevant_file(filepath: Path, allowed_extensions: Optional[Set[str]] = None) -> bool:
    if allowed_extensions is not None:
        if filepath.suffix.lower() not in allowed_extensions:
            return False

    return not is_binary_file(filepath)


def collect_target(
    target_path: Path,
    filter_engine: ExclusionFilter,
    allowed_extensions: Optional[Set[str]] = None
) -> List[Tuple[Path, str]]:
    target_path = target_path.resolve()

    if target_path.is_file():
        if not filter_engine.is_ignored(target_path, is_dir=False):
            if is_relevant_file(target_path, allowed_extensions):
                try:
                    rel_path = target_path.relative_to(PROJECT_ROOT).as_posix()
                except ValueError:
                    rel_path = target_path.name
                return [(target_path, rel_path)]
        return []

    collected: List[Tuple[Path, str]] = []
    for root, dirs, files in os.walk(target_path):
        # Pruning directories in-place prevents descending into huge ignored subtrees
        dirs[:] = [
            d for d in dirs
            if not filter_engine.is_ignored(Path(root) / d, is_dir=True)
        ]

        for file in files:
            filepath = Path(root) / file
            if filter_engine.is_ignored(filepath, is_dir=False):
                continue
            if is_relevant_file(filepath, allowed_extensions):
                try:
                    rel_path = filepath.relative_to(PROJECT_ROOT).as_posix()
                except ValueError:
                    rel_path = filepath.name
                collected.append((filepath, rel_path))

    collected.sort(key=lambda x: x[1])
    return collected


def read_file_content(filepath: Path) -> str:
    try:
        return filepath.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        try:
            return filepath.read_text(encoding='latin-1')
        except Exception as err:
            return f"[ERROR READING FILE: {err}]"
    except Exception as err:
        return f"[ERROR READING FILE: {err}]"


def build_bundle_string(collected: List[Tuple[Path, str]], target_label: str) -> str:
    lines = [
        f"# Workspace Context: {PROJECT_ROOT.name}",
        f"# Target Scope: {target_label}",
        f"# Total Files: {len(collected)}",
        f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "#" + "=" * 78,
        "\n"
    ]

    for filepath, rel_path in collected:
        content = read_file_content(filepath)
        lines.append("=" * 80)
        lines.append(f"# FILE: {rel_path}")
        lines.append("=" * 80 + "\n")
        lines.append(content)
        if content and not content.endswith('\n'):
            lines.append('\n')
        lines.append('\n')

    return '\n'.join(lines)


def copy_to_clipboard(text: str) -> bool:
    try:
        if sys.platform == 'win32' or os.name == 'nt':
            cmd = ['clip.exe']
        elif sys.platform == 'darwin':
            cmd = ['pbcopy']
        else:
            cmd = ['xclip', '-selection', 'clipboard']

        process = subprocess.Popen(cmd, stdin=subprocess.PIPE, close_fds=True)
        process.communicate(input=text.encode('utf-8'))
        return process.returncode == 0
    except Exception:
        return False


def open_in_editor(text: str, title_hint: str) -> bool:
    temp_dir = Path(tempfile.gettempdir())
    sanitized_hint = re.sub(r'[^a-zA-Z0-9_-]', '_', title_hint)[:32]
    temp_file = temp_dir / f"workspace_context_{sanitized_hint}_{datetime.now().strftime('%H%M%S')}.txt"
    temp_file.write_text(text, encoding='utf-8')

    try:
        if sys.platform == 'win32' or os.name == 'nt':
            subprocess.Popen(['notepad.exe', str(temp_file)])
        elif sys.platform == 'darwin':
            subprocess.Popen(['open', '-t', str(temp_file)])
        else:
            editor = os.environ.get('EDITOR')
            subprocess.Popen([editor, str(temp_file)] if editor else ['xdg-open', str(temp_file)])
        return True
    except Exception as err:
        print(f"[WARN] Could not launch text editor: {err}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Collect workspace context into clipboard and Notepad using .gitignore-style exclusion rules.'
    )
    parser.add_argument(
        'targets',
        nargs='*',
        default=['all'],
        help="Target scope, folders, or files (e.g., 'all', 'src', 'server.py'). Defaults to 'all'."
    )
    parser.add_argument(
        '--output', '-o',
        default=None,
        help='Optional: explicitly save bundle to a file'
    )
    parser.add_argument(
        '--list-only', '-l',
        action='store_true',
        help='List matched files without opening Notepad or copying'
    )
    parser.add_argument(
        '--exclusions', '-e',
        default=None,
        help=f"Optional: path to custom exclusion file (defaults to '{EXCLUSIONS_FILENAME}')"
    )
    parser.add_argument(
        '--no-gitignore',
        action='store_true',
        help='Disable reading .gitignore'
    )
    parser.add_argument(
        '--no-exclusions-file',
        action='store_true',
        help=f'Disable reading {EXCLUSIONS_FILENAME}'
    )
    parser.add_argument(
        '--ext',
        nargs='*',
        default=None,
        help="Optional: filter by file extensions (e.g., --ext .py .js .ts)"
    )

    args = parser.parse_args()

    use_git = USE_GITIGNORE and not args.no_gitignore
    use_custom = USE_EXCLUSIONS_FILE and not args.no_exclusions_file
    custom_exclusions = Path(args.exclusions) if args.exclusions else None

    filter_engine = ExclusionFilter(
        root_dir=PROJECT_ROOT,
        script_path=Path(__file__),
        use_gitignore=use_git,
        use_exclusions_file=use_custom,
        custom_file_path=custom_exclusions
    )

    allowed_exts: Optional[Set[str]] = None
    if args.ext:
        allowed_exts = {e.lower() if e.startswith('.') else f".{e.lower()}" for e in args.ext}

    targets_to_scan: List[Tuple[str, Path]] = []
    seen_paths: Set[Path] = set()

    for raw in args.targets:
        key = raw.strip().lower()
        if key == 'all':
            t_path = PROJECT_ROOT.resolve()
            if t_path not in seen_paths:
                targets_to_scan.append(('all', t_path))
                seen_paths.add(t_path)
        else:
            custom_path = (PROJECT_ROOT / raw).resolve()
            if custom_path.exists() and custom_path not in seen_paths:
                targets_to_scan.append((custom_path.name, custom_path))
                seen_paths.add(custom_path)
            else:
                print(f"[SKIP] Target path not found: {raw}", file=sys.stderr)

    if not targets_to_scan:
        print("[WARN] No valid targets found.", file=sys.stderr)
        return 1

    all_collected: List[Tuple[Path, str]] = []
    seen_file_paths: Set[Path] = set()

    for label, t_path in targets_to_scan:
        print(f"[SCAN] Collecting target: {label}")
        files = collect_target(t_path, filter_engine, allowed_exts)
        for f_path, rel_path in files:
            if f_path not in seen_file_paths:
                all_collected.append((f_path, rel_path))
                seen_file_paths.add(f_path)

    if not all_collected:
        print("[WARN] No matching files found to collect.", file=sys.stderr)
        return 1

    if args.list_only:
        print(f"\n[FOUND] {len(all_collected)} file(s):")
        for _, rel_path in all_collected:
            print(f"  * {rel_path}")
        return 0

    target_label = "_".join(t[0] for t in targets_to_scan)
    full_bundle = build_bundle_string(all_collected, target_label)

    if args.output:
        out_path = Path(args.output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(full_bundle, encoding='utf-8')
        print(f"[OK] Context saved to: {out_path}")

    if copy_to_clipboard(full_bundle):
        print(f"[OK] Copied {len(all_collected)} file(s) to clipboard.")
    else:
        print("[WARN] Clipboard copy failed or tool not available.")

    open_in_editor(full_bundle, target_label)
    print(f"[OK] Opened {len(all_collected)} file(s) in editor.")

    return 0


if __name__ == '__main__':
    sys.exit(main())