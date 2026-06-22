/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_")
  const orders = app.findCollectionByNameOrId("pbc_3527180448")
  const applications = app.findCollectionByNameOrId("pbc_2689671926")
  const tasks = app.findCollectionByNameOrId("pbc_2602490748")
  const feedbacks = app.findCollectionByNameOrId("pbc_440916241")

  const hasField = (collection, name) => {
    try {
      collection.fields.getByName(name)
      return true
    } catch (_) {
      return false
    }
  }

  if (!hasField(users, "role")) {
    users.fields.add(new Field({
      id: "select_role_001",
      name: "role",
      type: "select",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSelect: 1,
      values: ["customer", "executor", "support"]
    }))
  }

  if (!hasField(users, "birth_date")) {
    users.fields.add(new Field({
      id: "date_birth_001",
      name: "birth_date",
      type: "date",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: "",
      max: ""
    }))
  }

  if (!hasField(users, "description")) {
    users.fields.add(new Field({
      id: "text_desc_001",
      name: "description",
      type: "text",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 0,
      max: 0,
      pattern: "",
      autogeneratePattern: ""
    }))
  }

  if (!hasField(orders, "complexity_auto")) {
    orders.fields.add(new Field({
      id: "num_cauto_001",
      name: "complexity_auto",
      type: "number",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 1,
      max: 5,
      onlyInt: true
    }))
  }

  if (!hasField(orders, "complexity_factors")) {
    orders.fields.add(new Field({
      id: "json_cfactors_01",
      name: "complexity_factors",
      type: "json",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSize: 2000000
    }))
  }

  if (!hasField(applications, "complexity_proposed")) {
    applications.fields.add(new Field({
      id: "num_cprop_001",
      name: "complexity_proposed",
      type: "number",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 1,
      max: 5,
      onlyInt: true
    }))
  }

  if (!hasField(applications, "complexity_reason")) {
    applications.fields.add(new Field({
      id: "text_creason_01",
      name: "complexity_reason",
      type: "text",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 0,
      max: 0,
      pattern: "",
      autogeneratePattern: ""
    }))
  }

  if (!hasField(tasks, "complexity_final")) {
    tasks.fields.add(new Field({
      id: "num_cfinal_001",
      name: "complexity_final",
      type: "number",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 1,
      max: 5,
      onlyInt: true
    }))
  }

  if (!hasField(tasks, "complexity_source")) {
    tasks.fields.add(new Field({
      id: "select_csrc_001",
      name: "complexity_source",
      type: "select",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSelect: 1,
      values: ["auto", "executor_adjusted", "manual"]
    }))
  }

  if (!hasField(feedbacks, "reviewer_id")) {
    feedbacks.fields.add(new Field({
      id: "rel_reviewer_01",
      name: "reviewer_id",
      type: "relation",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      collectionId: "_pb_users_auth_",
      cascadeDelete: false,
      minSelect: 0,
      maxSelect: 1
    }))
  }

  if (!hasField(feedbacks, "reviewed_user_id")) {
    feedbacks.fields.add(new Field({
      id: "rel_reviewed_01",
      name: "reviewed_user_id",
      type: "relation",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      collectionId: "_pb_users_auth_",
      cascadeDelete: false,
      minSelect: 0,
      maxSelect: 1
    }))
  }

  if (!hasField(feedbacks, "type")) {
    feedbacks.fields.add(new Field({
      id: "select_ftype_01",
      name: "type",
      type: "select",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSelect: 1,
      values: ["customer_to_executor", "executor_to_customer"]
    }))
  }

  app.save(users)
  app.save(orders)
  app.save(applications)
  app.save(tasks)
  app.save(feedbacks)
}, (app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_")
  const orders = app.findCollectionByNameOrId("pbc_3527180448")
  const applications = app.findCollectionByNameOrId("pbc_2689671926")
  const tasks = app.findCollectionByNameOrId("pbc_2602490748")
  const feedbacks = app.findCollectionByNameOrId("pbc_440916241")

  const removeField = (collection, name) => {
    try {
      const field = collection.fields.getByName(name)
      collection.fields.removeById(field.id)
    } catch (_) {}
  }

  removeField(users, "role")
  removeField(users, "birth_date")
  removeField(users, "description")

  removeField(orders, "complexity_auto")
  removeField(orders, "complexity_factors")

  removeField(applications, "complexity_proposed")
  removeField(applications, "complexity_reason")

  removeField(tasks, "complexity_final")
  removeField(tasks, "complexity_source")

  removeField(feedbacks, "reviewer_id")
  removeField(feedbacks, "reviewed_user_id")
  removeField(feedbacks, "type")

  app.save(users)
  app.save(orders)
  app.save(applications)
  app.save(tasks)
  app.save(feedbacks)
})