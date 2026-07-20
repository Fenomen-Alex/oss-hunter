# Installing OSS Hunter for OpenCode

## Installation

Add oss-hunter to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["oss-hunter@git+https://github.com/<your-username>/oss-hunter.git"]
}
```

Restart OpenCode. Then use `/oss-hunter` in your chat.

To pin a specific version:

```json
{
  "plugin": ["oss-hunter@git+https://github.com/<your-username>/oss-hunter.git#v0.1.0"]
}
```
