/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const supportRequests = app.findCollectionByNameOrId("support_requests")

  const hasField = (collection, name) => {
    try {
      collection.fields.getByName(name)
      return true
    } catch (_) {
      return false
    }
  }

  if (!hasField(users, "is_banned")) {
    users.fields.add(
      new Field({
        id: "boolisbanned01",
        name: "is_banned",
        type: "bool",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
      }),
    )
  }

  if (!hasField(users, "ban_reason")) {
    users.fields.add(
      new Field({
        id: "textbanreason01",
        name: "ban_reason",
        type: "text",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
        min: 0,
        max: 0,
        pattern: "",
        autogeneratePattern: "",
      }),
    )
  }

  if (!hasField(users, "banned_at")) {
    users.fields.add(
      new Field({
        id: "datebannedat01",
        name: "banned_at",
        type: "date",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
      }),
    )
  }

  if (!hasField(users, "gender")) {
    users.fields.add(
      new Field({
        id: "selectgender01",
        name: "gender",
        type: "select",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
        maxSelect: 1,
        values: ["male", "female"],
      }),
    )
  }

  users.updateRule =
    'id = @request.auth.id || (@request.auth.id != "" && @request.auth.role = "support")'
  app.save(users)

  if (!hasField(supportRequests, "status")) {
    supportRequests.fields.add(
      new Field({
        id: "selectsupstatus1",
        name: "status",
        type: "select",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
        maxSelect: 1,
        values: ["open", "closed"],
      }),
    )
  }

  if (!hasField(supportRequests, "closed_at")) {
    supportRequests.fields.add(
      new Field({
        id: "datesupclosed1",
        name: "closed_at",
        type: "date",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
      }),
    )
  }

  app.save(supportRequests)

  const genderByEmail = {
    "customer@test.ru": "male",
    "executor@test.ru": "male",
    "support@test.ru": "female",
    "anna.customer@test.ru": "female",
    "max.executor@test.ru": "male",
    "elena.executor@test.ru": "female",
    "ivan.executor@test.ru": "male",
  }

  for (const email in genderByEmail) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      record.set("gender", genderByEmail[email])
      app.save(record)
    } catch (_) {}
  }

  const orders = app.findRecordsByFilter("orders", "", "id", 500, 0)
  const sortedOrders = orders.slice().sort((a, b) => a.id.localeCompare(b.id))
  const baseMs = Date.now() - sortedOrders.length * 3600000

  for (let i = 0; i < sortedOrders.length; i++) {
    const stamp =
      new Date(baseMs + i * 3600000)
        .toISOString()
        .slice(0, 19)
        .replace("T", " ") + ".000Z"

    const record = sortedOrders[i]
    record.set("created", stamp)
    record.set("updated", stamp)
    app.save(record)
  }

  function statusId(collection, name) {
    try {
      return app.findFirstRecordByData(collection, "name", name).id
    } catch (_) {
      return null
    }
  }

  const payPaid = statusId("payment_statuses", "paid")
  const statusDone = statusId("task_statuses", "done")
  const statusProgress = statusId("task_statuses", "in_progress")

  let executor
  try {
    executor = app.findAuthRecordByEmail("users", "executor@test.ru")
  } catch (_) {
    executor = null
  }

  if (executor && payPaid && statusDone) {
    const crmOrders = app.findRecordsByFilter(
      "orders",
      `executor_id = "${executor.id}"`,
      "",
      20,
      0,
    )

    for (const order of crmOrders) {
      const tasks = app.findRecordsByFilter(
        "tasks",
        `order_id = "${order.id}"`,
        "",
      5,
        0,
      )

      for (const task of tasks) {
        task.set("executor_id", executor.id)
        task.set("payment_status_id", payPaid)
        task.set("status_id", statusDone)
        if (!task.get("estimated_time") || task.get("estimated_time") <= 0) {
          task.set("estimated_time", 40)
        }
        if (!task.get("time_spent") || task.get("time_spent") <= 0) {
          task.set("time_spent", 32)
        }
        app.save(task)
      }
    }

    const paidSamples = [
      { hoursEst: 24, hoursSpent: 20, price: 52000 },
      { hoursEst: 18, hoursSpent: 16, price: 38000 },
      { hoursEst: 30, hoursSpent: 28, price: 61000 },
    ]

    const customer = app.findAuthRecordByEmail("users", "customer@test.ru")
    const react = app.findFirstRecordByData("frameworks", "name", "React")
    const js = app.findFirstRecordByData("languages", "name", "JavaScript")

    for (let i = 0; i < paidSamples.length; i++) {
      const sample = paidSamples[i]
      const title = `[DEMO] Выполненный заказ ${i + 1} (Андрей)`

      let order
      try {
        order = app.findFirstRecordByData("orders", "task_description", title)
      } catch (_) {
        order = new Record(app.findCollectionByNameOrId("orders"))
        order.set("customer_id", customer.id)
        order.set("executor_id", executor.id)
        order.set("framework_id", react.id)
        order.set("language_id", js.id)
        order.set("task_description", title)
        order.set("deadline", "2026-04-15 00:00:00.000Z")
        order.set("price", sample.price)
        order.set("complexity_auto", 3)
        order.set("complexity_factors", "[]")
        app.save(order)
      }

      let task
      const existingTasks = app.findRecordsByFilter(
        "tasks",
        `order_id = "${order.id}"`,
        "",
        1,
        0,
      )

      if (existingTasks.length > 0) {
        task = existingTasks[0]
      } else {
        task = new Record(app.findCollectionByNameOrId("tasks"))
        task.set("order_id", order.id)
      }

      task.set("executor_id", executor.id)
      task.set("status_id", statusDone)
      task.set("payment_status_id", payPaid)
      task.set("estimated_time", sample.hoursEst)
      task.set("time_spent", sample.hoursSpent)
      task.set("payment_amount", sample.price)
      task.set("complexity_final", 3)
      task.set("complexity_source", "auto")
      task.set("prepayment_required", false)
      app.save(task)
    }
  }

  const requests = app.findRecordsByFilter(
    "support_requests",
    "",
    "-id",
    500,
    0,
  )

  for (const request of requests) {
    if (!request.get("status")) {
      request.set("status", "open")
      app.save(request)
    }
  }
}, (app) => {
  // Irreversible data backfill.
})
