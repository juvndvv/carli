# SwiftUI migration checklist

Inventory of the Flutter app (`app/lib`) to track parity in the native iOS app (`ios/`).
Status as of 2026-10-28: ✅ native · 🟡 partial · ⬜ pending.

## Shell
- ✅ Launch
- ✅ Login (with 2FA code / recovery code)
- ✅ Lock screen (Face ID / Touch ID, `AppLock`)
- ✅ Home (Inicio), notification rows open their link
- ✅ Global search (sections + `v1/search`, opens movements in their sheet)
- ✅ Notifications inbox (pages, read/unread swipe, delete one / read / all)
- ✅ Pending items screen (filters, inline actions per type, undo, similar categorization)
- ✅ More screen → replaced by the tab bar + Ajustes (logout lives in Ajustes)
- ✅ Coming-soon modules (listed under Ajustes › Módulos › Próximamente)
- ✅ Settings: root, profile, appearance, modules, notifications (push + per type), security (password, 2FA with QR and recovery codes, Face ID, sessions)
- ✅ Deep links: Flutter routes → tab + section + pushed screens (`AppLink`)

## Finanzas
- ✅ Resumen
- ✅ Movimientos (list, search, filters, swipe delete, link filters: dates, amounts, tags, debt, recurring, contact)
- 🟡 Movimientos tools: more-filters sheet, multi-select bulk edit, CSV export
- ✅ Presupuestos
- 🟡 Transaction sheet (create / edit; tags, splits and shares still read-only)
- ✅ Similar categorization offer after categorizing an import
- ✅ Accounts, bank connections and link flow, categories and tags, debts, goals, recurring, shared, finance settings

## Tareas
- ✅ Hoy, Próximas, Listas, list detail, task detail, new task, templates, settings

## Notas
- ✅ Notes home, folders, archive / trash, text and checklist editors, shopping list, restock, settings

## Hábitos
- ✅ Hoy, list, progress, detail, editor, log / break / convert sheets, settings

## Cross-cutting
- ✅ Push notifications (APNs registration, taps open their route, test push)
- ✅ Home-screen quick actions
- ✅ Share sheet (`ShareLink`) and QR codes (Core Image)
- ✅ Session refresh (pending + unread every 2 min while open)
- ⬜ Offline notes database (`drift`): the native app is online-only by decision; writes are optimistic and synced right away
