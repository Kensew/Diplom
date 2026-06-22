/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const orders = app.findCollectionByNameOrId("orders")

  const hasField = (name) => {
    try {
      orders.fields.getByName(name)
      return true
    } catch (_) {
      return false
    }
  }

  if (!hasField("created")) {
    orders.fields.add(
      new AutodateField({
        name: "created",
        onCreate: true,
        onUpdate: false,
      }),
    )
  }

  if (!hasField("updated")) {
    orders.fields.add(
      new AutodateField({
        name: "updated",
        onCreate: true,
        onUpdate: true,
      }),
    )
  }

  app.save(orders)

  const records = app.findRecordsByFilter("orders", "", "id", 500, 0)
  const sorted = records.slice().sort((a, b) => a.id.localeCompare(b.id))
  const baseMs = Date.now() - sorted.length * 3600000

  for (let i = 0; i < sorted.length; i++) {
    const stamp =
      new Date(baseMs + i * 3600000)
        .toISOString()
        .slice(0, 19)
        .replace("T", " ") + ".000Z"

    const record = sorted[i]
    record.set("created", stamp)
    record.set("updated", stamp)
    app.save(record)
  }
}, (app) => {
  const orders = app.findCollectionByNameOrId("orders")

  const removeField = (name) => {
    try {
      const field = orders.fields.getByName(name)
      orders.fields.removeById(field.id)
    } catch (_) {}
  }

  removeField("created")
  removeField("updated")
  app.save(orders)
})
