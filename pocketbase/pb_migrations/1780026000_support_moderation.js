/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  const hasField = (collection, name) => {
    try {
      collection.fields.getByName(name)
      return true
    } catch (_) {
      return false
    }
  }

  if (!hasField(users, "is_banned")) {
    users.fields.add(new Field({
      id: "boolisbanned01",
      name: "is_banned",
      type: "bool",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
    }))
  }

  if (!hasField(users, "ban_reason")) {
    users.fields.add(new Field({
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
    }))
  }

  if (!hasField(users, "banned_at")) {
    users.fields.add(new Field({
      id: "datebannedat01",
      name: "banned_at",
      type: "date",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
    }))
  }

  users.updateRule =
    'id = @request.auth.id || @request.auth.role = "support"'

  app.save(users)
}, (app) => {
  const users = app.findCollectionByNameOrId("users")

  const removeField = (name) => {
    try {
      const field = users.fields.getByName(name)
      users.fields.removeById(field.id)
    } catch (_) {}
  }

  removeField("is_banned")
  removeField("ban_reason")
  removeField("banned_at")

  users.updateRule = "id = @request.auth.id"
  app.save(users)
})
