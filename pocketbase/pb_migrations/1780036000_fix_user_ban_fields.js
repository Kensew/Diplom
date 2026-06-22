/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_")

  const hasField = (collection, name) => {
    try {
      collection.fields.getByName(name)
      return true
    } catch (_) {
      return false
    }
  }

  if (!hasField(users, "role")) {
    users.fields.add(
      new Field({
        id: "selectrole004",
        name: "role",
        type: "select",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
        maxSelect: 1,
        values: ["customer", "executor", "support"],
      }),
    )
  }

  if (!hasField(users, "is_banned")) {
    users.fields.add(
      new Field({
        id: "boolisbanned02",
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
        id: "textbanreason02",
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
        id: "datebannedat02",
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
        id: "selectgender02",
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

  const supportEmails = {
    "support@test.ru": "support",
    "customer@test.ru": "customer",
    "executor@test.ru": "executor",
    "anna.customer@test.ru": "customer",
    "max.executor@test.ru": "executor",
    "elena.executor@test.ru": "executor",
    "ivan.executor@test.ru": "executor",
  }

  for (const email in supportEmails) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      if (record.get("role") == null || record.get("role") === "") {
        record.set("role", supportEmails[email])
      }
      if (record.get("is_banned") == null) {
        record.set("is_banned", false)
      }
      app.save(record)
    } catch (_) {}
  }
}, (app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_")
  users.updateRule = "id = @request.auth.id"
  app.save(users)
})
