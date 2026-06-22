migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  function upsertUser({
    email,
    password,
    name,
    role,
    birthDate,
    age,
    description,
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
    record.set("birth_date", birthDate)
    record.set("age", age)
    record.set("description", description)

    try {
      record.set("verified", true)
    } catch (_) {}

    app.save(record)
  }

  upsertUser({
    email: "dev1@test.local",
    password: "12345678",
    name: "Dev Заказчик",
    role: "customer",
    birthDate: "2000-01-01 00:00:00.000Z",
    age: 26,
    description: "Dev account: 1 / 1",
  })

  upsertUser({
    email: "dev2@test.local",
    password: "12345678",
    name: "Dev Исполнитель",
    role: "executor",
    birthDate: "2000-01-01 00:00:00.000Z",
    age: 26,
    description: "Dev account: 2 / 2",
  })

  upsertUser({
    email: "dev3@test.local",
    password: "12345678",
    name: "Dev Поддержка",
    role: "support",
    birthDate: "2000-01-01 00:00:00.000Z",
    age: 26,
    description: "Dev account: 3 / 3",
  })
}, (app) => {
  const emails = [
    "dev1@test.local",
    "dev2@test.local",
    "dev3@test.local",
  ]

  for (const email of emails) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      app.delete(record)
    } catch (_) {}
  }
})