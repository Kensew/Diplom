/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const orders = app.findCollectionByNameOrId("orders")
  const applications = app.findCollectionByNameOrId("applications")
  const paymentRequests = app.findCollectionByNameOrId("payment_requests")
  const tasks = app.findCollectionByNameOrId("tasks")

  const hasField = (collection, name) => {
    const field = collection.fields.getByName(name)
    return field !== null && field !== undefined
  }

  if (!hasField(orders, "prepayment_required")) {
    orders.fields.add(new Field({
      id: "boolprepayreq01",
      name: "prepayment_required",
      type: "bool",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
    }))
  }

  if (!hasField(orders, "prepayment_percent")) {
    orders.fields.add(new Field({
      id: "numprepaypct01",
      name: "prepayment_percent",
      type: "number",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 10,
      max: 100,
    }))
  }

  if (!hasField(applications, "requires_prepayment")) {
    applications.fields.add(new Field({
      id: "boolappprepay01",
      name: "requires_prepayment",
      type: "bool",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
    }))
  }

  if (!hasField(applications, "prepayment_note")) {
    applications.fields.add(new Field({
      id: "textappprepay01",
      name: "prepayment_note",
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

  if (!hasField(paymentRequests, "payment_type")) {
    paymentRequests.fields.add(new Field({
      id: "selectpaytype01",
      name: "payment_type",
      type: "select",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      maxSelect: 1,
      values: ["prepayment", "final"],
    }))
  }

  if (!hasField(tasks, "prepayment_required")) {
    tasks.fields.add(new Field({
      id: "booltaskprepay01",
      name: "prepayment_required",
      type: "bool",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
    }))
  }

  if (!hasField(tasks, "prepayment_percent")) {
    tasks.fields.add(new Field({
      id: "numtaskprepay01",
      name: "prepayment_percent",
      type: "number",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      min: 10,
      max: 100,
    }))
  }

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

  ensureRecord("payment_statuses", "name", "awaiting_prepayment")
  ensureRecord("payment_statuses", "name", "prepayment_paid")

  app.save(orders)
  app.save(applications)
  app.save(paymentRequests)
  app.save(tasks)
}, (app) => {
  const orders = app.findCollectionByNameOrId("orders")
  const applications = app.findCollectionByNameOrId("applications")
  const paymentRequests = app.findCollectionByNameOrId("payment_requests")
  const tasks = app.findCollectionByNameOrId("tasks")

  const removeField = (collection, name) => {
    const field = collection.fields.getByName(name)

    if (field !== null && field !== undefined) {
      collection.fields.removeById(field.id)
    }
  }

  removeField(orders, "prepayment_required")
  removeField(orders, "prepayment_percent")
  removeField(applications, "requires_prepayment")
  removeField(applications, "prepayment_note")
  removeField(paymentRequests, "payment_type")
  removeField(tasks, "prepayment_required")
  removeField(tasks, "prepayment_percent")

  app.save(orders)
  app.save(applications)
  app.save(paymentRequests)
  app.save(tasks)
})
