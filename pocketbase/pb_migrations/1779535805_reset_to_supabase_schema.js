migrate((app) => {
  const authOnly = '@request.auth.id != ""'

  function deleteCollection(name) {
    try {
      const c = app.findCollectionByNameOrId(name)
      app.delete(c)
    } catch (_) {}
  }

  // Удаляем старые прикладные коллекции в порядке зависимостей.
  [
    "support_request_attachments",
    "task_message_attachments",
    "support_requests_messages",
    "support_requests",
    "tasks_messages",
    "payment_requests",
    "feedbacks",
    "applications",
    "order_attachments",
    "tasks",
    "orders",
    "payment_statuses",
    "task_statuses",
    "languages",
    "frameworks",
  ].forEach(deleteCollection)

  const users = app.findCollectionByNameOrId("users")

  function removeUserField(name) {
    try {
      users.fields.removeByName(name)
    } catch (_) {}
  }

  function addUserField(field) {
    try {
      users.fields.getByName(field.name)
    } catch (_) {
      users.fields.add(field)
    }
  }

  // Кастомные поля users.
  ;["role", "birth_date", "description", "photo", "age", "last_login"].forEach(removeUserField)

  addUserField({
    type: "select",
    name: "role",
    required: false,
    values: ["customer", "executor", "support"],
    maxSelect: 1,
  })

  addUserField({
    type: "date",
    name: "birth_date",
    required: false,
  })

  addUserField({
    type: "text",
    name: "description",
    required: false,
  })

  addUserField({
    type: "text",
    name: "photo",
    required: false,
  })

  addUserField({
    type: "number",
    name: "age",
    required: false,
    onlyInt: true,
    min: 0,
  })

  addUserField({
    type: "date",
    name: "last_login",
    required: false,
  })

  // Dev rules. Потом ужесточим.
  users.listRule = authOnly
  users.viewRule = authOnly
  users.createRule = ""
  users.updateRule = "id = @request.auth.id"
  users.deleteRule = null

  app.save(users)

  const frameworks = new Collection({
    type: "base",
    name: "frameworks",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        type: "text",
        name: "name",
        required: true,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_frameworks_name ON frameworks (name)",
    ],
  })
  app.save(frameworks)

  const languages = new Collection({
    type: "base",
    name: "languages",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        type: "text",
        name: "name",
        required: true,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_languages_name ON languages (name)",
    ],
  })
  app.save(languages)

  const paymentStatuses = new Collection({
    type: "base",
    name: "payment_statuses",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        type: "text",
        name: "name",
        required: true,
      },
    ],
  })
  app.save(paymentStatuses)

  const taskStatuses = new Collection({
    type: "base",
    name: "task_statuses",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        type: "text",
        name: "name",
        required: true,
      },
    ],
  })
  app.save(taskStatuses)

  const orders = new Collection({
    type: "base",
    name: "orders",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "executor_id",
        required: false,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "customer_id",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "framework_id",
        required: false,
        collectionId: frameworks.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "language_id",
        required: false,
        collectionId: languages.id,
        maxSelect: 1,
      },
      {
        type: "text",
        name: "task_description",
        required: true,
      },
      {
        type: "date",
        name: "deadline",
        required: false,
      },
      {
        type: "number",
        name: "price",
        required: false,
        min: 0,
      },
    ],
  })
  app.save(orders)

  const orderAttachments = new Collection({
    type: "base",
    name: "order_attachments",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "order_id",
        required: true,
        collectionId: orders.id,
        maxSelect: 1,
      },
      {
        type: "text",
        name: "url",
        required: false,
      },
      {
        type: "file",
        name: "file",
        required: false,
        maxSelect: 1,
      },
    ],
  })
  app.save(orderAttachments)

  const applications = new Collection({
    type: "base",
    name: "applications",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "order_id",
        required: true,
        collectionId: orders.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "executor_id",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "select",
        name: "status",
        required: false,
        values: ["pending", "approved", "rejected"],
        maxSelect: 1,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_applications_order_executor ON applications (order_id, executor_id)",
    ],
  })
  app.save(applications)

  const tasks = new Collection({
    type: "base",
    name: "tasks",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "order_id",
        required: true,
        collectionId: orders.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "status_id",
        required: false,
        collectionId: taskStatuses.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "payment_status_id",
        required: false,
        collectionId: paymentStatuses.id,
        maxSelect: 1,
      },
      {
        type: "number",
        name: "estimated_time",
        required: false,
        min: 0,
      },
      {
        type: "number",
        name: "time_spent",
        required: false,
        min: 0,
      },
      {
        type: "number",
        name: "payment_amount",
        required: false,
        min: 0,
      },
      {
        type: "relation",
        name: "executor_id",
        required: false,
        collectionId: users.id,
        maxSelect: 1,
      },
    ],
  })
  app.save(tasks)

  const paymentRequests = new Collection({
    type: "base",
    name: "payment_requests",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "task_id",
        required: true,
        collectionId: tasks.id,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "requested_by",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "select",
        name: "status",
        required: false,
        values: ["pending", "approved", "rejected"],
        maxSelect: 1,
      },
      {
        type: "number",
        name: "payment_amount",
        required: false,
        min: 0,
      },
    ],
  })
  app.save(paymentRequests)

  const feedbacks = new Collection({
    type: "base",
    name: "feedbacks",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "number",
        name: "estimate",
        required: true,
        onlyInt: true,
        min: 1,
        max: 5,
      },
      {
        type: "text",
        name: "text",
        required: true,
      },
      {
        type: "relation",
        name: "order_id",
        required: true,
        collectionId: orders.id,
        maxSelect: 1,
      },
    ],
  })
  app.save(feedbacks)

  const supportRequests = new Collection({
    type: "base",
    name: "support_requests",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "user_id",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "text",
        name: "reason",
        required: true,
      },
    ],
  })
  app.save(supportRequests)

  const supportRequestsMessages = new Collection({
    type: "base",
    name: "support_requests_messages",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "user_id",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "text",
        name: "text",
        required: true,
      },
      {
        type: "relation",
        name: "request_id",
        required: true,
        collectionId: supportRequests.id,
        maxSelect: 1,
      },
    ],
  })
  app.save(supportRequestsMessages)

  const supportRequestAttachments = new Collection({
    type: "base",
    name: "support_request_attachments",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "file",
        name: "photo",
        required: true,
        maxSelect: 1,
      },
      {
        type: "relation",
        name: "support_request_message_id",
        required: true,
        collectionId: supportRequestsMessages.id,
        maxSelect: 1,
      },
    ],
  })
  app.save(supportRequestAttachments)

  const tasksMessages = new Collection({
    type: "base",
    name: "tasks_messages",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "user_id",
        required: true,
        collectionId: users.id,
        maxSelect: 1,
      },
      {
        type: "text",
        name: "text",
        required: true,
      },
      {
        type: "relation",
        name: "task_id",
        required: true,
        collectionId: tasks.id,
        maxSelect: 1,
      },
    ],
  })
  app.save(tasksMessages)

  const taskMessageAttachments = new Collection({
    type: "base",
    name: "task_message_attachments",
    listRule: authOnly,
    viewRule: authOnly,
    createRule: authOnly,
    updateRule: authOnly,
    deleteRule: authOnly,
    fields: [
      {
        type: "relation",
        name: "task_message_id",
        required: true,
        collectionId: tasksMessages.id,
        maxSelect: 1,
      },
      {
        type: "file",
        name: "photo",
        required: true,
        maxSelect: 1,
      },
    ],
  })
  app.save(taskMessageAttachments)

  function ensureRecord(collectionName, fieldName, value) {
    try {
      app.findFirstRecordByData(collectionName, fieldName, value)
      return
    } catch (_) {
      const collection = app.findCollectionByNameOrId(collectionName)
      const record = new Record(collection)
      record.set(fieldName, value)
      app.save(record)
    }
  }

  ;["Flutter", "React", "Django"].forEach((name) => {
    ensureRecord("frameworks", "name", name)
  })

  ;["Dart", "JavaScript", "Python"].forEach((name) => {
    ensureRecord("languages", "name", name)
  })

  ;["new", "in_progress", "checking", "done", "cancelled"].forEach((name) => {
    ensureRecord("task_statuses", "name", name)
  })

  ;["none", "pending", "approved", "rejected", "paid"].forEach((name) => {
    ensureRecord("payment_statuses", "name", name)
  })

  function ensureUser(email, password, name, role) {
    try {
      app.findAuthRecordByEmail("users", email)
      return
    } catch (_) {
      const record = new Record(users)
      record.set("email", email)
      record.set("password", password)
      record.set("passwordConfirm", password)
      record.set("verified", true)
      record.set("name", name)
      record.set("role", role)
      app.save(record)
    }
  }

  ensureUser("customer@test.ru", "12345678", "Customer Test", "customer")
  ensureUser("executor@test.ru", "12345678", "Executor Test", "executor")
  ensureUser("support@test.ru", "12345678", "Support Test", "support")
}, (app) => {
  function deleteCollection(name) {
    try {
      const c = app.findCollectionByNameOrId(name)
      app.delete(c)
    } catch (_) {}
  }

  [
    "support_request_attachments",
    "task_message_attachments",
    "support_requests_messages",
    "support_requests",
    "tasks_messages",
    "payment_requests",
    "feedbacks",
    "applications",
    "order_attachments",
    "tasks",
    "orders",
    "payment_statuses",
    "task_statuses",
    "languages",
    "frameworks",
  ].forEach(deleteCollection)

  try {
    const users = app.findCollectionByNameOrId("users")

    ;["role", "birth_date", "description", "photo", "age", "last_login"].forEach((name) => {
      try {
        users.fields.removeByName(name)
      } catch (_) {}
    })

    users.listRule = null
    users.viewRule = null
    users.createRule = null
    users.updateRule = null
    users.deleteRule = null

    app.save(users)
  } catch (_) {}
})