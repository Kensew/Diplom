migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  // users fields
  try { users.fields.getByName("role") } catch {
    users.fields.add(new SelectField({
      name: "role",
      required: true,
      values: ["customer", "executor", "support"],
      maxSelect: 1,
    }))
  }

  try { users.fields.getByName("birth_date") } catch {
    users.fields.add(new DateField({
      name: "birth_date",
      required: false,
    }))
  }

  try { users.fields.getByName("description") } catch {
    users.fields.add(new TextField({
      name: "description",
      required: false,
    }))
  }

  try { users.fields.getByName("age") } catch {
    users.fields.add(new NumberField({
      name: "age",
      required: false,
      onlyInt: true,
      min: 0,
    }))
  }

  try { users.fields.getByName("last_login") } catch {
    users.fields.add(new DateField({
      name: "last_login",
      required: false,
    }))
  }

  app.save(users)

  const frameworks = new Collection({
    type: "base",
    name: "frameworks",
    fields: [
      { name: "name", type: "text", required: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_frameworks_name ON frameworks (name)"
    ],
  })
  app.save(frameworks)

  const languages = new Collection({
    type: "base",
    name: "languages",
    fields: [
      { name: "name", type: "text", required: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_languages_name ON languages (name)"
    ],
  })
  app.save(languages)

  const orders = new Collection({
    type: "base",
    name: "orders",
    fields: [
      { name: "executor_id", type: "relation", required: false, collectionId: users.id, maxSelect: 1 },
      { name: "customer_id", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "framework_id", type: "relation", required: false, collectionId: frameworks.id, maxSelect: 1 },
      { name: "language_id", type: "relation", required: false, collectionId: languages.id, maxSelect: 1 },
      { name: "task_description", type: "text", required: true },
      { name: "deadline", type: "date", required: false },
      { name: "price", type: "number", required: false, min: 0 },
      { name: "attachment", type: "file", required: false, maxSelect: 1 },
    ],
  })
  app.save(orders)

  const applications = new Collection({
    type: "base",
    name: "applications",
    fields: [
      { name: "order_id", type: "relation", required: true, collectionId: orders.id, maxSelect: 1 },
      { name: "executor_id", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "status", type: "select", required: true, values: ["pending", "approved", "rejected"], maxSelect: 1 },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_applications_order_executor ON applications (order_id, executor_id)"
    ],
  })
  app.save(applications)

  const tasks = new Collection({
    type: "base",
    name: "tasks",
    fields: [
      { name: "order_id", type: "relation", required: true, collectionId: orders.id, maxSelect: 1 },
      { name: "executor_id", type: "relation", required: false, collectionId: users.id, maxSelect: 1 },
      { name: "status", type: "select", required: true, values: ["new", "in_progress", "checking", "done", "cancelled"], maxSelect: 1 },
      { name: "payment_status", type: "select", required: true, values: ["none", "pending", "approved", "rejected", "paid"], maxSelect: 1 },
      { name: "estimated_time", type: "number", required: false, min: 0 },
      { name: "time_spent", type: "number", required: false, min: 0 },
      { name: "payment_amount", type: "number", required: false, min: 0 },
    ],
  })
  app.save(tasks)

  const paymentRequests = new Collection({
    type: "base",
    name: "payment_requests",
    fields: [
      { name: "task_id", type: "relation", required: true, collectionId: tasks.id, maxSelect: 1 },
      { name: "requested_by", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "status", type: "select", required: true, values: ["pending", "approved", "rejected"], maxSelect: 1 },
      { name: "payment_amount", type: "number", required: false, min: 0 },
    ],
  })
  app.save(paymentRequests)

  const tasksMessages = new Collection({
    type: "base",
    name: "tasks_messages",
    fields: [
      { name: "user_id", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "task_id", type: "relation", required: true, collectionId: tasks.id, maxSelect: 1 },
      { name: "text", type: "text", required: true },
      { name: "photo", type: "file", required: false, maxSelect: 1 },
    ],
  })
  app.save(tasksMessages)

  const supportRequests = new Collection({
    type: "base",
    name: "support_requests",
    fields: [
      { name: "user_id", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "reason", type: "text", required: true },
      { name: "status", type: "select", required: true, values: ["open", "closed"], maxSelect: 1 },
    ],
  })
  app.save(supportRequests)

  const supportRequestsMessages = new Collection({
    type: "base",
    name: "support_requests_messages",
    fields: [
      { name: "user_id", type: "relation", required: true, collectionId: users.id, maxSelect: 1 },
      { name: "request_id", type: "relation", required: true, collectionId: supportRequests.id, maxSelect: 1 },
      { name: "text", type: "text", required: true },
      { name: "photo", type: "file", required: false, maxSelect: 1 },
    ],
  })
  app.save(supportRequestsMessages)

  const feedbacks = new Collection({
    type: "base",
    name: "feedbacks",
    fields: [
      { name: "estimate", type: "number", required: true, onlyInt: true, min: 1, max: 5 },
      { name: "text", type: "text", required: true },
      { name: "order_id", type: "relation", required: true, collectionId: orders.id, maxSelect: 1 },
    ],
  })
  app.save(feedbacks)
}, (app) => {
  const names = [
    "feedbacks",
    "support_requests_messages",
    "support_requests",
    "tasks_messages",
    "payment_requests",
    "tasks",
    "applications",
    "orders",
    "languages",
    "frameworks",
  ]

  for (const name of names) {
    try {
      const collection = app.findCollectionByNameOrId(name)
      app.delete(collection)
    } catch {}
  }

  const users = app.findCollectionByNameOrId("users")
  for (const field of ["role", "birth_date", "description", "age", "last_login"]) {
    try {
      users.fields.removeByName(field)
    } catch {}
  }
  app.save(users)
})