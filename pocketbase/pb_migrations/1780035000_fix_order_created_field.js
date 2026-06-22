/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const orders = app.findCollectionByNameOrId("pbc_3527180448")

  const hasField = (name) => {
    try {
      const field = orders.fields.getByName(name)
      return field !== null && field !== undefined
    } catch (_) {
      return false
    }
  }

  if (!hasField("order_created")) {
    orders.fields.add(
      new Field({
        id: "dateordercreated1",
        name: "order_created",
        type: "date",
        system: false,
        required: false,
        hidden: false,
        presentable: false,
        min: "",
        max: "",
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
    record.set("order_created", stamp)
    app.save(record)
  }
}, (app) => {
  const orders = app.findCollectionByNameOrId("pbc_3527180448")

  try {
    const field = orders.fields.getByName("order_created")
    orders.fields.removeById(field.id)
    app.save(orders)
  } catch (_) {}
})
