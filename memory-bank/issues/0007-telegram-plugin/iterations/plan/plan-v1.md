# Plan v1 — Issue #7

План ограничивает код пятью файлами в allowlist, выносит всю Telegram-специфику в отдельный plugin class, а проверку строит через two-tier gate: targeted rspec на plugin + весь `spec/core/collect` как regression.
