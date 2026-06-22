/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const languages = app.findCollectionByNameOrId("languages")
  const frameworks = app.findCollectionByNameOrId("frameworks")
  const orders = app.findCollectionByNameOrId("orders")
  const applications = app.findCollectionByNameOrId("applications")
  const tasks = app.findCollectionByNameOrId("tasks")
  const feedbacks = app.findCollectionByNameOrId("feedbacks")
  const taskMessages = app.findCollectionByNameOrId("tasks_messages")

  const DEMO = "[DEMO] "

  function ensureLanguage(name) {
    try {
      return app.findFirstRecordByData("languages", "name", name)
    } catch (_) {
      const record = new Record(languages)
      record.set("name", name)
      app.save(record)
      return record
    }
  }

  function ensureFramework(name, languageName) {
    let record

    try {
      record = app.findFirstRecordByData("frameworks", "name", name)
    } catch (_) {
      record = new Record(frameworks)
      record.set("name", name)
      app.save(record)
    }

    const language = ensureLanguage(languageName)
    record.set("language_id", language.id)
    app.save(record)

    return record
  }

  function findUser(email) {
    return app.findAuthRecordByEmail("users", email)
  }

  function findByName(collection, name) {
    return app.findFirstRecordByData(collection, "name", name)
  }

  function findOrder(description) {
    return app.findFirstRecordByData("orders", "task_description", description)
  }

  function statusId(collection, name) {
    return findByName(collection, name).id
  }

  function ensureOrder(description, apply) {
    try {
      return app.findFirstRecordByData("orders", "task_description", description)
    } catch (_) {
      const record = new Record(orders)
      apply(record)
      app.save(record)
      return record
    }
  }

  function ensureApplication(orderId, executorId, apply) {
    const all = app.findRecordsByFilter(
      "applications",
      `order_id = "${orderId}" && executor_id = "${executorId}"`,
      "",
      1,
      0,
    )

    if (all.length > 0) {
      return all[0]
    }

    const record = new Record(applications)
    apply(record)
    app.save(record)
    return record
  }

  function ensureTask(orderId, apply) {
    const all = app.findRecordsByFilter("tasks", `order_id = "${orderId}"`, "", 1, 0)

    if (all.length > 0) {
      return all[0]
    }

    const record = new Record(tasks)
    apply(record)
    app.save(record)
    return record
  }

  function ensureFeedback(orderId, apply) {
    const all = app.findRecordsByFilter(
      "feedbacks",
      `order_id = "${orderId}"`,
      "",
      1,
      0,
    )

    if (all.length > 0) {
      return all[0]
    }

    const record = new Record(feedbacks)
    apply(record)
    app.save(record)
    return record
  }

  function ensureTaskMessage(taskId, userId, text) {
    const all = app.findRecordsByFilter(
      "tasks_messages",
      `task_id = "${taskId}" && text = "${text}"`,
      "",
      1,
      0,
    )

    if (all.length > 0) {
      return all[0]
    }

    const record = new Record(taskMessages)
    record.set("task_id", taskId)
    record.set("user_id", userId)
    record.set("text", text)
    app.save(record)
    return record
  }

  // --- Справочники: языки и фреймворки ---

  ensureLanguage("TypeScript")
  ensureLanguage("Go")

  // Dart
  ensureFramework("Serverpod", "Dart")
  ensureFramework("Flame", "Dart")

  // JavaScript
  ensureFramework("Angular", "JavaScript")
  ensureFramework("Next.js", "JavaScript")
  ensureFramework("Nuxt", "JavaScript")
  ensureFramework("Express", "JavaScript")
  ensureFramework("Svelte", "JavaScript")

  // Python
  ensureFramework("Flask", "Python")

  // TypeScript
  ensureFramework("NestJS", "TypeScript")

  // Go
  ensureFramework("Gin", "Go")

  const customer = findUser("customer@test.ru")
  const anna = findUser("anna.customer@test.ru")
  const executor = findUser("executor@test.ru")
  const max = findUser("max.executor@test.ru")
  const elena = findUser("elena.executor@test.ru")
  const ivan = findUser("ivan.executor@test.ru")

  const dart = findByName("languages", "Dart")
  const js = findByName("languages", "JavaScript")
  const python = findByName("languages", "Python")
  const ts = findByName("languages", "TypeScript")
  const go = findByName("languages", "Go")

  const flutter = findByName("frameworks", "Flutter")
  const serverpod = findByName("frameworks", "Serverpod")
  const flame = findByName("frameworks", "Flame")
  const react = findByName("frameworks", "React")
  const angular = findByName("frameworks", "Angular")
  const nextjs = findByName("frameworks", "Next.js")
  const flask = findByName("frameworks", "Flask")
  const nestjs = findByName("frameworks", "NestJS")
  const gin = findByName("frameworks", "Gin")

  const statusProgress = statusId("task_statuses", "in_progress")
  const statusDone = statusId("task_statuses", "done")
  const payNone = statusId("payment_statuses", "none")
  const payPaid = statusId("payment_statuses", "paid")

  // --- Дополнительные демо-заказы ---

  ensureOrder(`${DEMO}Бэкенд на Serverpod`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", serverpod.id)
    record.set("language_id", dart.id)
    record.set("task_description", `${DEMO}Бэкенд на Serverpod`)
    record.set("deadline", "2026-08-20 00:00:00.000Z")
    record.set("price", 45000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
    record.set("prepayment_required", true)
    record.set("prepayment_percent", 40)
  })

  ensureOrder(`${DEMO}Мобильная игра на Flame`, (record) => {
    record.set("customer_id", anna.id)
    record.set("framework_id", flame.id)
    record.set("language_id", dart.id)
    record.set("task_description", `${DEMO}Мобильная игра на Flame`)
    record.set("deadline", "2026-10-01 00:00:00.000Z")
    record.set("price", 95000)
    record.set("complexity_auto", 5)
    record.set("complexity_factors", "[]")
  })

  ensureOrder(`${DEMO}Корпоративный портал на Angular`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", angular.id)
    record.set("language_id", js.id)
    record.set("task_description", `${DEMO}Корпоративный портал на Angular`)
    record.set("deadline", "2026-09-10 00:00:00.000Z")
    record.set("price", 78000)
    record.set("complexity_auto", 4)
    record.set("complexity_factors", "[]")
  })

  ensureOrder(`${DEMO}SSR-сайт на Next.js`, (record) => {
    record.set("customer_id", anna.id)
    record.set("framework_id", nextjs.id)
    record.set("language_id", js.id)
    record.set("task_description", `${DEMO}SSR-сайт на Next.js`)
    record.set("deadline", "2026-08-01 00:00:00.000Z")
    record.set("price", 55000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  ensureOrder(`${DEMO}API на Flask`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", flask.id)
    record.set("language_id", python.id)
    record.set("task_description", `${DEMO}API на Flask`)
    record.set("deadline", "2026-07-25 00:00:00.000Z")
    record.set("price", 22000)
    record.set("complexity_auto", 2)
    record.set("complexity_factors", "[]")
  })

  ensureOrder(`${DEMO}Микросервис на NestJS`, (record) => {
    record.set("customer_id", anna.id)
    record.set("framework_id", nestjs.id)
    record.set("language_id", ts.id)
    record.set("task_description", `${DEMO}Микросервис на NestJS`)
    record.set("deadline", "2026-08-12 00:00:00.000Z")
    record.set("price", 48000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  const orderGo = ensureOrder(`${DEMO}REST-сервис на Gin`, (record) => {
    record.set("customer_id", customer.id)
    record.set("executor_id", ivan.id)
    record.set("framework_id", gin.id)
    record.set("language_id", go.id)
    record.set("task_description", `${DEMO}REST-сервис на Gin`)
    record.set("deadline", "2026-08-08 00:00:00.000Z")
    record.set("price", 36000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  const taskGo = ensureTask(orderGo.id, (record) => {
    record.set("order_id", orderGo.id)
    record.set("executor_id", ivan.id)
    record.set("status_id", statusProgress)
    record.set("payment_status_id", payNone)
    record.set("estimated_time", 25)
    record.set("time_spent", 8)
    record.set("payment_amount", 36000)
    record.set("complexity_final", 3)
    record.set("complexity_source", "auto")
  })

  ensureApplication(orderGo.id, ivan.id, (record) => {
    record.set("order_id", orderGo.id)
    record.set("executor_id", ivan.id)
    record.set("status", "approved")
    record.set("source", "executor_apply")
    record.set("initiator_id", ivan.id)
    record.set("message", "Пишу на Go, Gin использую регулярно.")
    record.set("complexity_proposed", 3)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", false)
    record.set("prepayment_note", "")
  })

  ensureTaskMessage(
    taskGo.id,
    customer.id,
    "Нужен эндпоинт для экспорта отчётов в CSV.",
  )
  ensureTaskMessage(
    taskGo.id,
    ivan.id,
    "Сделаю к пятнице, уточню формат колонок.",
  )

  const orderDone = findOrder(`${DEMO}Корпоративный сайт`)

  ensureFeedback(orderDone.id, (record) => {
    record.set("order_id", orderDone.id)
    record.set("estimate", 5)
    record.set("text", "Отличная работа, всё сдано в срок. Рекомендую!")
    record.set("reviewer_id", customer.id)
    record.set("reviewed_user_id", elena.id)
    record.set("type", "customer_to_executor")
  })

  const orderCrm = findOrder(`${DEMO}CRM для менеджеров`)
  const taskCrm = app.findRecordsByFilter(
    "tasks",
    `order_id = "${orderCrm.id}"`,
    "",
    1,
    0,
  )[0]

  if (taskCrm) {
    ensureTaskMessage(
      taskCrm.id,
      customer.id,
      "Добавьте фильтр по дате в списке сделок.",
    )
    ensureTaskMessage(
      taskCrm.id,
      executor.id,
      "Фильтр готов, проверьте на тестовых данных.",
    )
  }

  const orderServerpod = findOrder(`${DEMO}Бэкенд на Serverpod`)
  ensureApplication(orderServerpod.id, max.id, (record) => {
    record.set("order_id", orderServerpod.id)
    record.set("executor_id", max.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", max.id)
    record.set("message", "Serverpod + Flutter — мой основной стек.")
    record.set("complexity_proposed", 3)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", true)
    record.set("prepayment_note", "Только с предоплатой")
  })

  const orderNext = findOrder(`${DEMO}SSR-сайт на Next.js`)
  ensureApplication(orderNext.id, ivan.id, (record) => {
    record.set("order_id", orderNext.id)
    record.set("executor_id", ivan.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", ivan.id)
    record.set("message", "Next.js 14, App Router, SEO настрою.")
    record.set("complexity_proposed", 3)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", false)
    record.set("prepayment_note", "")
  })
}, (app) => {
  const DEMO = "[DEMO] "

  const extraOrderTitles = [
    `${DEMO}Бэкенд на Serverpod`,
    `${DEMO}Мобильная игра на Flame`,
    `${DEMO}Корпоративный портал на Angular`,
    `${DEMO}SSR-сайт на Next.js`,
    `${DEMO}API на Flask`,
    `${DEMO}Микросервис на NestJS`,
    `${DEMO}REST-сервис на Gin`,
  ]

  for (const title of extraOrderTitles) {
    try {
      const order = app.findFirstRecordByData("orders", "task_description", title)
      const orderId = order.id

      try {
        const feedbacks = app.findRecordsByFilter(
          "feedbacks",
          `order_id = "${orderId}"`,
          "",
          50,
          0,
        )
        for (const item of feedbacks) {
          app.delete(item)
        }
      } catch (_) {}

      try {
        const tasks = app.findRecordsByFilter("tasks", `order_id = "${orderId}"`, "", 50, 0)
        for (const task of tasks) {
          const messages = app.findRecordsByFilter(
            "tasks_messages",
            `task_id = "${task.id}"`,
            "",
            50,
            0,
          )
          for (const message of messages) {
            app.delete(message)
          }
          app.delete(task)
        }
      } catch (_) {}

      try {
        const apps = app.findRecordsByFilter(
          "applications",
          `order_id = "${orderId}"`,
          "",
          50,
          0,
        )
        for (const appRecord of apps) {
          app.delete(appRecord)
        }
      } catch (_) {}

      app.delete(order)
    } catch (_) {}
  }

  try {
    const orderDone = app.findFirstRecordByData(
      "orders",
      "task_description",
      `${DEMO}Корпоративный сайт`,
    )
    const feedbacks = app.findRecordsByFilter(
      "feedbacks",
      `order_id = "${orderDone.id}"`,
      "",
      50,
      0,
    )
    for (const item of feedbacks) {
      app.delete(item)
    }
  } catch (_) {}

  try {
    const orderCrm = app.findFirstRecordByData(
      "orders",
      "task_description",
      `${DEMO}CRM для менеджеров`,
    )
    const tasks = app.findRecordsByFilter("tasks", `order_id = "${orderCrm.id}"`, "", 50, 0)
    for (const task of tasks) {
      const messages = app.findRecordsByFilter(
        "tasks_messages",
        `task_id = "${task.id}"`,
        "",
        50,
        0,
      )
      for (const message of messages) {
        app.delete(message)
      }
    }
  } catch (_) {}

  for (const name of [
    "Serverpod",
    "Flame",
    "Angular",
    "Next.js",
    "Nuxt",
    "Express",
    "Svelte",
    "Flask",
    "NestJS",
    "Gin",
  ]) {
    try {
      app.delete(app.findFirstRecordByData("frameworks", "name", name))
    } catch (_) {}
  }

  for (const name of ["TypeScript", "Go"]) {
    try {
      app.delete(app.findFirstRecordByData("languages", "name", name))
    } catch (_) {}
  }
})
