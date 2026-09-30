# AI_Studio_Protocol (Universal LLM & VS Code Workflow Contract)

> **Scope:** Project-agnostic operational contract for AI assistants (Google AI Studio, Claude, ChatGPT) working with human operators inside VS Code.  
> **Portability:** Universal. Can be dropped into any software, embedded, or infrastructure repository.

---

## 1. THE CODE-FIRST VS. DOC-FINISHER CADENCE

1. **Separation of Concerns:**  
   * Executable logic, scripts, and configuration belong in dedicated source files (`.py`, `.sh`, `.js`, `.json`).  
   * Documentation (`.md`) is reserved for architecture, runbooks, operational lifecycles, and failure triage.  
2. **Finisher Rule:**  
   * Active engineering occurs in source files.  
   * Do not update documentation on every minor code tweak. Documentation updates are "Finishers" applied only when a milestone is verified operational.

---

## 2. ARTIFACT DELIVERY MODES

To prevent cognitive fatigue and token waste, AI assistants must deliver artifacts in one of two standardized modes:

### Mode A: Full Artifact Delivery (New Files / Complete Overhauls)
Used exclusively when creating a new file or performing a total structural rewrite:
* Wrapped in an outer fence of **four backticks** (` ````markdown ` or ` ````text `).
* **Pure Content Only:** The content inside the fence must be 100% ready for 1-click copy-pasting into the target file. Never include meta-commentary, placeholders, or conversational remarks inside the artifact box.

### Mode B: Direct Pastable Find-and-Replace (Targeted Edits)
Used for localized updates, bug fixes, or config changes. AI assistants must provide a two-box target:
1. **Target File:** Relative path to the file.
2. **Find in file (`Ctrl+F`):** A minimal, unique 1–3 line anchor snippet.
3. **Replace with:** A clean, copyable code box containing **strictly the replacement lines** (no diff markers, no metadata headers).

---

## 3. UI RENDERING & PARSER SAFETY (THE STRICT N+1 INVARIANT)

To prevent web Markdown renderers (such as Google AI Studio Playground) from suffering from parser inversion, broken code boxes, or swallowed text:

1. **The Strict $N+1$ Rule:**  
   Any outer code block containing nested code fences must have strictly more backticks than the longest fence inside it:
   $$\text{Outer Ticks} = \max(\text{Inner Ticks}) + 1$$
   * Standard code snippets (no inner fences): **3 backticks** (` ``` `).
   * Documents or patches containing standard code: **4 backticks** (` ```` `).
   * Meta-documentation explaining 4-tick blocks: **5 backticks** (` ```` ` ````).
2. **Schema Sanitization:**  
   When illustrating patch schemas inside documentation, use standard 3 backticks or indented blocks so that the parent document can always be safely transmitted in 4 backticks.

---

## 4. CROSS-PLATFORM TERMINAL EXECUTION

To prevent string escaping collisions, shell syntax errors, and newline mangling:

1. **Windows PowerShell (Verbatim String Piping):**  
   Multi-line shell scripts, ADB commands, or SSH pipes from PowerShell must use literal single-quoted heredocs:
   ```powershell
   @'
   # Pure Linux syntax here. No escaping of quotes (") or variables ($) required.
   echo "Hello from Linux"
   '@ | adb shell su
   ```
   * Never use nested double quotes (`"su -c '...'"`).  
   * Never rely on un-documented personal session aliases (e.g., `asu`).
2. **Unix / POSIX Shells:**  
   Use standard heredocs (`cat << 'EOF' | ...`) or direct stdin redirection. Avoid terminal multiplexer wrapper traps (e.g. Kitty's `kitten ssh`).

---

## 5. CONTEXT WINDOW & TOKEN BUDGET HYGIENE

1. **Selective Context Ingestion:**  
   When feeding project state to the AI, exclude compiled binaries, package locks, large log dumps, and `.git` trees.
2. **Pruning Legacy Runs:**  
   Operators should periodically clear lengthy terminal logs and past diagnostic sessions to keep the model's attention heads focused on the active architectural state.