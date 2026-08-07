# Worked examples

Four files, so you open the one you need.

| | |
|---|---|
| [architecture.md](architecture.md) | file layout, the `part` macro, slots over argument drilling, context for global state, atomicity, no DB in views, how to test |
| [tooling.md](tooling.md) | `view_component-contrib`, base classes, sidecar previews and Lookbook, i18n, registering a Stimulus controller, the query linter |
| [styling.md](styling.md) | the `style` DSL as `cva`, `tailwind_merge`, passing HTML attributes through, and this repo's merge precedence |
| [official.md](official.md) | the framework's own best practices: the two places they contradict the articles, and the seven rules the articles do not cover |

Code marked **This repo** is copied from the working source and can be relied
on. Code marked **From the article** is the reference implementation, which this
repo sometimes deliberately does not follow — [SKILL.md](../SKILL.md#where-this-repo-departs)
says where and why.
