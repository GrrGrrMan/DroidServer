import fnmatch
import pathlib

# Gitignore-style list of patterns to ignore
IGNORE_PATTERNS = [
    # Project defaults
    ".venv",
    ".pio",
    "__pycache__",
    ".git",

    # dependencies
    "/node_modules",
    "/.pnp",
    ".pnp.js",
    # testing
    "/coverage",

    # production
    "/build",

    # misc
    ".DS_Store",
    ".env.local",
    ".env.development.local",
    ".env.test.local",
    ".env.production.local",

    "npm-debug.log*",
    "yarn-debug.log*",
    "yarn-error.log*",
    ".rooignore",
    ".cache",
    "node_modules"

]

def should_ignore(path, root_path, patterns):
    rel_path = path.relative_to(root_path)
    rel_path_str = rel_path.as_posix()
    name = path.name
    
    for pattern in patterns:
        p = pattern.strip()
        # Skip empty lines or comments
        if not p or p.startswith("#"):
            continue
            
        p = p.removesuffix("/")
            
        # Pattern matches relative to the root (starts with '/')
        if p.startswith("/"):
            p_no_lead = p[1:]
            if fnmatch.fnmatch(rel_path_str, p_no_lead):
                return True
        # Globstar pattern (starts with '**/')
        elif p.startswith("**/"):
            if fnmatch.fnmatch(rel_path_str, p) or fnmatch.fnmatch(rel_path_str, p[3:]):
                return True
        else:
            # Matches file/directory name anywhere in the tree (no slashes in pattern)
            if "/" not in p:
                if fnmatch.fnmatch(name, p):
                    return True
            # Matches against the relative path
            else:
                if fnmatch.fnmatch(rel_path_str, p):
                    return True
                
    return False

def print_tree(path, root_path, prefix=""):
    try:
        # Pre-filter entries to avoid recursively entering ignored directories
        entries = sorted([
            e for e in path.iterdir() 
            if not should_ignore(e, root_path, IGNORE_PATTERNS)
        ])
    except PermissionError:
        return

    count = len(entries)
    
    for i, entry in enumerate(entries):
        is_last = (i == count - 1)
        connector = "└── " if is_last else "├── "
        print(f"{prefix}{connector}{entry.name}")
        
        if entry.is_dir():
            new_prefix = prefix + ("    " if is_last else "│   ")
            print_tree(entry, root_path, new_prefix)

if __name__ == "__main__":
    root_directory = pathlib.Path(".")
    print(f"{root_directory.resolve().name}/")
    print_tree(root_directory, root_directory)