/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  function relationId(value) {
    if (value == null) return null
    if (typeof value === "string") {
      const trimmed = value.trim()
      return trimmed.length === 0 ? null : trimmed
    }
    if (Array.isArray(value) && value.length > 0 && typeof value[0] === "string") {
      const trimmed = value[0].trim()
      return trimmed.length === 0 ? null : trimmed
    }
    return null
  }

  function setAvatar(record, seed) {
    try {
      const url =
        "https://api.dicebear.com/7.x/notionists/png?seed=" +
        encodeURIComponent(seed) +
        "&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc"
      record.set("photo", $filesystem.fileFromURL(url, 30))
    } catch (_) {}
  }

  function upsertUser({
    email,
    password,
    name,
    role,
    description,
    birthDate,
    age,
    avatarSeed,
  }) {
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

    if (birthDate) record.set("birth_date", birthDate)
    if (age != null) record.set("age", age)
    record.set("is_banned", false)
    record.set("ban_reason", "")

    try {
      record.set("verified", true)
    } catch (_) {}

    if (avatarSeed) setAvatar(record, avatarSeed)

    app.save(record)
    return record
  }

  function deleteRecordsByFilter(collection, filter, limit) {
    try {
      return app.findRecordsByFilter(collection, filter, "", limit || 500, 0)
    } catch (_) {
      return []
    }
  }

  function deleteOrderCascade(orderId) {
    const tasks = deleteRecordsByFilter("tasks", `order_id = "${orderId}"`, 50)

    for (const task of tasks) {
      const payments = deleteRecordsByFilter(
        "payment_requests",
        `task_id = "${task.id}"`,
        50,
      )
      for (const payment of payments) app.delete(payment)

      const messages = deleteRecordsByFilter(
        "tasks_messages",
        `task_id = "${task.id}"`,
        100,
      )
      for (const message of messages) {
        const attachments = deleteRecordsByFilter(
          "task_message_attachments",
          `task_message_id = "${message.id}"`,
          50,
        )
        for (const attachment of attachments) app.delete(attachment)
        app.delete(message)
      }

      app.delete(task)
    }

    const apps = deleteRecordsByFilter("applications", `order_id = "${orderId}"`, 50)
    for (const application of apps) app.delete(application)

    const attachments = deleteRecordsByFilter(
      "order_attachments",
      `order_id = "${orderId}"`,
      50,
    )
    for (const attachment of attachments) app.delete(attachment)

    const feedbacks = deleteRecordsByFilter("feedbacks", `order_id = "${orderId}"`, 50)
    for (const feedback of feedbacks) app.delete(feedback)

    try {
      const order = app.findRecordById("orders", orderId)
      app.delete(order)
    } catch (_) {}
  }

  function deleteUserCascade(userId) {
    const orders = deleteRecordsByFilter(
      "orders",
      `customer_id = "${userId}" || executor_id = "${userId}"`,
      500,
    )
    for (const order of orders) {
      deleteOrderCascade(order.id)
    }

    const orphanApps = deleteRecordsByFilter(
      "applications",
      `executor_id = "${userId}"`,
      200,
    )
    for (const application of orphanApps) app.delete(application)

    const orphanTasks = deleteRecordsByFilter(
      "tasks",
      `executor_id = "${userId}"`,
      200,
    )
    for (const task of orphanTasks) {
      const payments = deleteRecordsByFilter(
        "payment_requests",
        `task_id = "${task.id}"`,
        50,
      )
      for (const payment of payments) app.delete(payment)
      app.delete(task)
    }

    const feedbacks = deleteRecordsByFilter(
      "feedbacks",
      `reviewer_id = "${userId}" || reviewed_user_id = "${userId}"`,
      200,
    )
    for (const feedback of feedbacks) app.delete(feedback)

    const supportRequests = deleteRecordsByFilter(
      "support_requests",
      `user_id = "${userId}"`,
      200,
    )
    for (const request of supportRequests) {
      const messages = deleteRecordsByFilter(
        "support_requests_messages",
        `request_id = "${request.id}"`,
        200,
      )
      for (const message of messages) {
        const attachments = deleteRecordsByFilter(
          "support_request_attachments",
          `support_request_message_id = "${message.id}"`,
          50,
        )
        for (const attachment of attachments) app.delete(attachment)
        app.delete(message)
      }
      app.delete(request)
    }
  }

  function deleteUserByEmail(email) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      deleteUserCascade(record.id)
      app.delete(record)
    } catch (_) {}
  }

  function deleteUsersByName(name) {
    const found = deleteRecordsByFilter("users", `name = "${name}"`, 50)
    for (const record of found) {
      deleteUserCascade(record.id)
      app.delete(record)
    }
  }

  // Удаляем странные и дублирующие аккаунты.
  for (const email of [
    "dev1@test.local",
    "dev2@test.local",
    "dev3@test.local",
  ]) {
    deleteUserByEmail(email)
  }

  deleteUsersByName("1")
  deleteUsersByName("2")

  // Обновляем «dan», если остался после ручной регистрации.
  const danUsers = deleteRecordsByFilter(
    "users",
    `name = "dan" || email ~ "dan"`,
    10,
  )
  for (const record of danUsers) {
    record.set("name", "Даниил Кравцов")
    record.set("role", "customer")
    record.set("description", "Заказчик, ищет разработчиков для pet-проектов")
    record.set("birth_date", "1995-09-03 00:00:00.000Z")
    record.set("age", 30)
    setAvatar(record, "Daniel")
    app.save(record)
  }

  const password = "12345678"

  upsertUser({
    email: "customer@test.ru",
    password,
    name: "Павел Соколов",
    role: "customer",
    description: "Заказчик IT-проектов, стартапы и лендинги",
    birthDate: "1992-04-12 00:00:00.000Z",
    age: 33,
    avatarSeed: "PavelSokolov",
  })

  upsertUser({
    email: "executor@test.ru",
    password,
    name: "Андрей Климов",
    role: "executor",
    description: "Fullstack-разработчик, React и Python",
    birthDate: "1994-11-20 00:00:00.000Z",
    age: 31,
    avatarSeed: "AndreyKlimov",
  })

  upsertUser({
    email: "support@test.ru",
    password,
    name: "Ольга Морозова",
    role: "support",
    description: "Сотрудник службы поддержки платформы",
    birthDate: "1990-02-08 00:00:00.000Z",
    age: 35,
    avatarSeed: "OlgaMorozova",
  })

  upsertUser({
    email: "anna.customer@test.ru",
    password,
    name: "Анна Петрова",
    role: "customer",
    description: "Заказчик мобильных и веб-приложений",
    birthDate: "1993-06-15 00:00:00.000Z",
    age: 32,
    avatarSeed: "AnnaPetrova",
  })

  upsertUser({
    email: "max.executor@test.ru",
    password,
    name: "Максим Орлов",
    role: "executor",
    description: "Flutter / Dart разработчик",
    birthDate: "1996-01-28 00:00:00.000Z",
    age: 29,
    avatarSeed: "MaximOrlov",
  })

  upsertUser({
    email: "elena.executor@test.ru",
    password,
    name: "Елена Смирнова",
    role: "executor",
    description: "React / Django fullstack",
    birthDate: "1991-10-05 00:00:00.000Z",
    age: 34,
    avatarSeed: "ElenaSmirnova",
  })

  upsertUser({
    email: "ivan.executor@test.ru",
    password,
    name: "Иван Кузнецов",
    role: "executor",
    description: "Веб-разработчик, Vue и Go",
    birthDate: "1997-07-19 00:00:00.000Z",
    age: 28,
    avatarSeed: "IvanKuznetsov",
  })
}, (app) => {
  // Не откатываем: удалённые аккаунты и загруженные аватары.
})
