---
name: TemplateGUI startup ordering
description: Startup dependencies and failure behavior for the visual TemplateGUI runtime
---

The visual TemplateGUI initializer must bind every helper it calls from the shared hub before creating controls; a missing exported helper can stop execution immediately after license validation, making the GUI appear to vanish.

**Why:** The license callback begins loading modules only after validation, so a runtime error in the final initializer looks like a successful key followed by a missing GUI.

**How to apply:** When adding or removing TemplateGUI modules, compare initializer dependencies with `ui_core.lua` exports and keep animation fallbacks from leaving the main window hidden.