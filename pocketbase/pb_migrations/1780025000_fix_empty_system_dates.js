/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const tables = [
    "orders",
    "applications",
    "tasks",
    "frameworks",
    "languages",
    "feedbacks",
    "payment_requests",
    "order_attachments",
    "support_requests",
    "support_requests_messages",
    "tasks_messages",
    "task_message_attachments",
    "support_request_attachments",
    "task_statuses",
    "payment_statuses",
  ]

  const db = app.db()

  for (const table of tables) {
    try {
      db.newQuery(
        `UPDATE ${table} SET created = datetime('now') WHERE created IS NULL OR created = ''`,
      ).execute()

      db.newQuery(
        `UPDATE ${table} SET updated = COALESCE(NULLIF(updated, ''), created, datetime('now')) WHERE updated IS NULL OR updated = ''`,
      ).execute()
    } catch (_) {}
  }
}, (app) => {
  // Irreversible data backfill.
})
