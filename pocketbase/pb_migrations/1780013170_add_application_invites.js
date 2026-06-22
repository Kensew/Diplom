/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const applications = app.findCollectionByNameOrId("pbc_2689671926")

  const hasField = (collection, name) => {
    const field = collection.fields.getByName(name)
    return field !== null && field !== undefined
  }

  if (!hasField(applications, "source")) {
    applications.fields.add(new Field({
      id: "selectappsrc01",
      name: "source",
      type: "select",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSelect: 1,
      values: ["executor_apply", "customer_invite"]
    }))
  }

  if (!hasField(applications, "initiator_id")) {
    applications.fields.add(new Field({
      id: "relappinit01",
      name: "initiator_id",
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

  if (!hasField(applications, "message")) {
    applications.fields.add(new Field({
      id: "textappmsg01",
      name: "message",
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

  app.save(applications)
}, (app) => {
  const applications = app.findCollectionByNameOrId("pbc_2689671926")

  const removeField = (collection, name) => {
    const field = collection.fields.getByName(name)

    if (field !== null && field !== undefined) {
      collection.fields.removeById(field.id)
    }
  }

  removeField(applications, "source")
  removeField(applications, "initiator_id")
  removeField(applications, "message")

  app.save(applications)
})