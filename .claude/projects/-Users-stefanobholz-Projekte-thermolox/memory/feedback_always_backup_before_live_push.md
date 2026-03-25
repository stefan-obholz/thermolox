---
name: Always duplicate theme before pushing to live
description: Create a Shopify theme duplicate before making changes to the live theme
type: feedback
---

Always create a duplicate theme in Shopify before pushing changes to live. Use `shopify theme push --unpublished -t "Backup YYYY-MM-DD"` with a full pull of the live theme.

**Why:** On 2026-03-25, multiple pushes to the live theme broke the site repeatedly. Having a Shopify-internal backup allows instant rollback via the admin.

**How to apply:** Before any live push session: pull entire live theme, push as unpublished duplicate, then begin work.
