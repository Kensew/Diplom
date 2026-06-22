/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const orders = app.findCollectionByNameOrId("orders")
  const applications = app.findCollectionByNameOrId("applications")
  const tasks = app.findCollectionByNameOrId("tasks")
  const paymentRequests = app.findCollectionByNameOrId("payment_requests")
  const frameworks = app.findCollectionByNameOrId("frameworks")

  const DEMO = "[DEMO] "

  function upsertUser({ email, password, name, role, description }) {
    let record

    try {
      record = app.findAuthRecordByEmail("users", email)
    } catch (_) {
      record = new Record(users)
      record.set("email", email)
    }

    record.set("password", password)
    record.set("passwordConfirm", password)
    record.set("name", name)
    record.set("role", role)
    record.set("description", description)

    try {
      record.set("verified", true)
    } catch (_) {}

    app.save(record)
    return record
  }

  function findUser(email) {
    return app.findAuthRecordByEmail("users", email)
  }

  function findByName(collection, name) {
    return app.findFirstRecordByData(collection, "name", name)
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

    try {
      const language = findByName("languages", languageName)
      record.set("language_id", language.id)
      app.save(record)
    } catch (_) {}

    return record
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

  ensureFramework("Vue", "JavaScript")
  ensureFramework("FastAPI", "Python")

  upsertUser({
    email: "anna.customer@test.ru",
    password: "12345678",
    name: "Анна Петрова",
    role: "customer",
    description: "Демо-заказчик",
  })

  upsertUser({
    email: "max.executor@test.ru",
    password: "12345678",
    name: "Максим Орлов",
    role: "executor",
    description: "Flutter / Dart разработчик",
  })

  upsertUser({
    email: "elena.executor@test.ru",
    password: "12345678",
    name: "Елена Смирнова",
    role: "executor",
    description: "React / Django fullstack",
  })

  upsertUser({
    email: "ivan.executor@test.ru",
    password: "12345678",
    name: "Иван Кузнецов",
    role: "executor",
    description: "Веб-разработчик",
  })

  const customer = findUser("customer@test.ru")
  const anna = findUser("anna.customer@test.ru")
  const executor = findUser("executor@test.ru")
  const max = findUser("max.executor@test.ru")
  const elena = findUser("elena.executor@test.ru")
  const ivan = findUser("ivan.executor@test.ru")

  const flutter = findByName("frameworks", "Flutter")
  const react = findByName("frameworks", "React")
  const django = findByName("frameworks", "Django")
  const vue = findByName("frameworks", "Vue")
  const fastapi = findByName("frameworks", "FastAPI")

  const dart = findByName("languages", "Dart")
  const js = findByName("languages", "JavaScript")
  const python = findByName("languages", "Python")

  const statusNew = statusId("task_statuses", "new")
  const statusProgress = statusId("task_statuses", "in_progress")
  const statusDone = statusId("task_statuses", "done")

  const payNone = statusId("payment_statuses", "none")
  const payPaid = statusId("payment_statuses", "paid")
  const payAwaiting = statusId("payment_statuses", "awaiting_prepayment")

  const orderOpen1 = ensureOrder(`${DEMO}Лендинг для стартапа`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", flutter.id)
    record.set("language_id", dart.id)
    record.set("task_description", `${DEMO}Лендинг для стартапа`)
    record.set("deadline", "2026-08-15 00:00:00.000Z")
    record.set("price", 18000)
    record.set("complexity_auto", 2)
    record.set("complexity_factors", "[]")
    record.set("prepayment_required", true)
    record.set("prepayment_percent", 50)
  })

  const orderOpen2 = ensureOrder(`${DEMO}Интернет-магазин на React`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", react.id)
    record.set("language_id", js.id)
    record.set("task_description", `${DEMO}Интернет-магазин на React`)
    record.set("deadline", "2026-09-01 00:00:00.000Z")
    record.set("price", 52000)
    record.set("complexity_auto", 4)
    record.set("complexity_factors", "[]")
    record.set("prepayment_required", false)
  })

  const orderOpen3 = ensureOrder(`${DEMO}REST API на Django`, (record) => {
    record.set("customer_id", anna.id)
    record.set("framework_id", django.id)
    record.set("language_id", python.id)
    record.set("task_description", `${DEMO}REST API на Django`)
    record.set("deadline", "2026-07-20 00:00:00.000Z")
    record.set("price", 35000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
    record.set("prepayment_required", true)
    record.set("prepayment_percent", 30)
  })

  ensureOrder(`${DEMO}Vue-панель аналитики`, (record) => {
    record.set("customer_id", anna.id)
    record.set("framework_id", vue.id)
    record.set("language_id", js.id)
    record.set("task_description", `${DEMO}Vue-панель аналитики`)
    record.set("deadline", "2026-08-30 00:00:00.000Z")
    record.set("price", 41000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  ensureOrder(`${DEMO}FastAPI микросервис`, (record) => {
    record.set("customer_id", customer.id)
    record.set("framework_id", fastapi.id)
    record.set("language_id", python.id)
    record.set("task_description", `${DEMO}FastAPI микросервис`)
    record.set("deadline", "2026-07-10 00:00:00.000Z")
    record.set("price", 28000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  const orderAssigned = ensureOrder(`${DEMO}CRM для менеджеров`, (record) => {
    record.set("customer_id", customer.id)
    record.set("executor_id", executor.id)
    record.set("framework_id", react.id)
    record.set("language_id", js.id)
    record.set("task_description", `${DEMO}CRM для менеджеров`)
    record.set("deadline", "2026-08-05 00:00:00.000Z")
    record.set("price", 67000)
    record.set("complexity_auto", 4)
    record.set("complexity_factors", "[]")
  })

  ensureTask(orderAssigned.id, (record) => {
    record.set("order_id", orderAssigned.id)
    record.set("executor_id", executor.id)
    record.set("status_id", statusProgress)
    record.set("payment_status_id", payNone)
    record.set("estimated_time", 40)
    record.set("time_spent", 12)
    record.set("payment_amount", 67000)
    record.set("complexity_final", 4)
    record.set("complexity_source", "auto")
    record.set("prepayment_required", false)
  })

  const orderPrepay = ensureOrder(`${DEMO}Flutter-приложение доставки`, (record) => {
    record.set("customer_id", anna.id)
    record.set("executor_id", max.id)
    record.set("framework_id", flutter.id)
    record.set("language_id", dart.id)
    record.set("task_description", `${DEMO}Flutter-приложение доставки`)
    record.set("deadline", "2026-09-15 00:00:00.000Z")
    record.set("price", 85000)
    record.set("complexity_auto", 4)
    record.set("complexity_factors", "[]")
    record.set("prepayment_required", true)
    record.set("prepayment_percent", 50)
  })

  const taskPrepay = ensureTask(orderPrepay.id, (record) => {
    record.set("order_id", orderPrepay.id)
    record.set("executor_id", max.id)
    record.set("status_id", statusNew)
    record.set("payment_status_id", payAwaiting)
    record.set("estimated_time", 60)
    record.set("time_spent", 0)
    record.set("payment_amount", 85000)
    record.set("complexity_final", 4)
    record.set("complexity_source", "auto")
    record.set("prepayment_required", true)
    record.set("prepayment_percent", 50)
  })

  const existingPrepay = app.findRecordsByFilter(
    "payment_requests",
    `task_id = "${taskPrepay.id}"`,
    "",
    10,
    0,
  )

  if (existingPrepay.length === 0) {
    const prepayRequest = new Record(paymentRequests)
    prepayRequest.set("task_id", taskPrepay.id)
    prepayRequest.set("requested_by", max.id)
    prepayRequest.set("status", "pending")
    prepayRequest.set("payment_amount", 42500)
    prepayRequest.set("payment_type", "prepayment")
    app.save(prepayRequest)
  }

  const orderDone = ensureOrder(`${DEMO}Корпоративный сайт`, (record) => {
    record.set("customer_id", customer.id)
    record.set("executor_id", elena.id)
    record.set("framework_id", django.id)
    record.set("language_id", python.id)
    record.set("task_description", `${DEMO}Корпоративный сайт`)
    record.set("deadline", "2026-05-01 00:00:00.000Z")
    record.set("price", 42000)
    record.set("complexity_auto", 3)
    record.set("complexity_factors", "[]")
  })

  ensureTask(orderDone.id, (record) => {
    record.set("order_id", orderDone.id)
    record.set("executor_id", elena.id)
    record.set("status_id", statusDone)
    record.set("payment_status_id", payPaid)
    record.set("estimated_time", 30)
    record.set("time_spent", 28)
    record.set("payment_amount", 42000)
    record.set("complexity_final", 3)
    record.set("complexity_source", "auto")
    record.set("prepayment_required", false)
  })

  ensureApplication(orderOpen1.id, max.id, (record) => {
    record.set("order_id", orderOpen1.id)
    record.set("executor_id", max.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", max.id)
    record.set("message", "Готов взять проект, есть опыт с Flutter.")
    record.set("complexity_proposed", 2)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", true)
    record.set("prepayment_note", "Начну после предоплаты 50%")
  })

  ensureApplication(orderOpen2.id, elena.id, (record) => {
    record.set("order_id", orderOpen2.id)
    record.set("executor_id", elena.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", elena.id)
    record.set("message", "Делала похожие магазины, могу показать кейсы.")
    record.set("complexity_proposed", 4)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", false)
    record.set("prepayment_note", "")
  })

  ensureApplication(orderOpen2.id, ivan.id, (record) => {
    record.set("order_id", orderOpen2.id)
    record.set("executor_id", ivan.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", ivan.id)
    record.set("message", "Предлагаю разбить на этапы и сдать MVP за 3 недели.")
    record.set("complexity_proposed", 3)
    record.set("complexity_reason", "MVP без полной интеграции оплаты")
    record.set("requires_prepayment", false)
    record.set("prepayment_note", "")
  })

  ensureApplication(orderOpen3.id, elena.id, (record) => {
    record.set("order_id", orderOpen3.id)
    record.set("executor_id", elena.id)
    record.set("status", "pending")
    record.set("source", "executor_apply")
    record.set("initiator_id", elena.id)
    record.set("message", "Специализируюсь на Django REST.")
    record.set("complexity_proposed", 3)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", true)
    record.set("prepayment_note", "Работаю только по предоплате")
  })

  ensureApplication(orderAssigned.id, executor.id, (record) => {
    record.set("order_id", orderAssigned.id)
    record.set("executor_id", executor.id)
    record.set("status", "approved")
    record.set("source", "executor_apply")
    record.set("initiator_id", executor.id)
    record.set("message", "Беру CRM в работу.")
    record.set("complexity_proposed", 4)
    record.set("complexity_reason", "")
    record.set("requires_prepayment", false)
    record.set("prepayment_note", "")
  })
}, (app) => {
  const DEMO = "[DEMO] "

  const demoOrders = app.findRecordsByFilter(
    "orders",
    `task_description ~ "${DEMO}"`,
    "",
    500,
    0,
  )

  for (const order of demoOrders) {
    const orderId = order.id

    try {
      const tasks = app.findRecordsByFilter("tasks", `order_id = "${orderId}"`, "", 50, 0)
      for (const task of tasks) {
        const payments = app.findRecordsByFilter(
          "payment_requests",
          `task_id = "${task.id}"`,
          "",
          50,
          0,
        )
        for (const payment of payments) {
          app.delete(payment)
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
  }

  for (const email of [
    "anna.customer@test.ru",
    "max.executor@test.ru",
    "elena.executor@test.ru",
    "ivan.executor@test.ru",
  ]) {
    try {
      app.delete(app.findAuthRecordByEmail("users", email))
    } catch (_) {}
  }

  for (const name of ["Vue", "FastAPI"]) {
    try {
      app.delete(app.findFirstRecordByData("frameworks", "name", name))
    } catch (_) {}
  }
})
