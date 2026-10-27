# SwiftUI migration checklist

Inventory of the Flutter app (`app/lib`) to track parity in the native iOS app (`ios/`).
Status as of 2026-10-27: ✅ native · 🟡 partial · ⬜ pending.

## Shell
- ✅ Launch
- ✅ Login
- ⬜ Lock screen (biometric unlock, `local_auth`)
- ✅ Home (Inicio)
- ⬜ Global search
- ⬜ Notifications inbox (list, read state, delete)
- ⬜ Pending items screen
- ⬜ More screen
- ⬜ Coming-soon module screen
- ⬜ Settings: general, profile, appearance, modules, notifications, security (password prompt)

## Finanzas
- ✅ Resumen
- ✅ Movimientos (list, search, filters, swipe delete)
- 🟡 Presupuestos (overview done; editor sheet not opening yet; copy from previous period)
- ⬜ Transaction sheet (create / edit movement, the "+" action)
- ⬜ Accounts list and account detail, account form
- ⬜ Bank connections and bank link flow
- ⬜ Categories (form, delete, tags)
- ⬜ Debts (list, detail, form)
- ⬜ Goals (list, detail, goal form, contributions)
- ⬜ Recurring rules (list, rule form, confirm occurrence)
- ⬜ Shared expenses and contacts
- ⬜ Finance settings (period start date)

## Tareas
- ⬜ Hoy, Próximas, Listas, list detail
- ⬜ Task detail, new task sheet, postpone sheet
- ⬜ Templates and template editor
- ⬜ Tasks settings

## Notas
- ⬜ Notes list and note editor
- ⬜ Shopping list (sheets)
- ⬜ Notes settings

## Hábitos
- ⬜ Hoy, list, progress
- ⬜ Habit detail and editor
- ⬜ Log, break and convert-template sheets
- ⬜ Habits settings

## Cross-cutting (Flutter plugins / core)
- ⬜ Push notifications (APNs registration, `PushBridge.swift` in the Flutter runner)
- ⬜ Offline cache and pending sync queue (`drift`, `core/pending`)
- ⬜ Biometric lock (`local_auth`)
- ⬜ Share sheet (`share_plus`)
- ⬜ QR codes (`qr_flutter`)
- ⬜ Home-screen quick actions (`quick_actions`)
- ⬜ File handling (`core/files`, `path_provider`)
- ⬜ Deep links / router (`go_router`)
