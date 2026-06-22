migrate((app) => {
  const orders = app.findCollectionByNameOrId("orders");
  const applications = app.findCollectionByNameOrId("applications");
  const tasks = app.findCollectionByNameOrId("tasks");

  function hasField(collection, name) {
    try {
      collection.fields.getByName(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  if (!hasField(orders, "complexity_auto")) {
    orders.fields.add(new NumberField({
      name: "complexity_auto",
      required: false,
      onlyInt: true,
      min: 1,
      max: 5
    }));
  }

  if (!hasField(orders, "complexity_factors")) {
    orders.fields.add(new TextField({
      name: "complexity_factors",
      required: false
    }));
  }

  if (!hasField(applications, "complexity_proposed")) {
    applications.fields.add(new NumberField({
      name: "complexity_proposed",
      required: false,
      onlyInt: true,
      min: 1,
      max: 5
    }));
  }

  if (!hasField(applications, "complexity_reason")) {
    applications.fields.add(new TextField({
      name: "complexity_reason",
      required: false
    }));
  }

  if (!hasField(tasks, "complexity_final")) {
    tasks.fields.add(new NumberField({
      name: "complexity_final",
      required: false,
      onlyInt: true,
      min: 1,
      max: 5
    }));
  }

  if (!hasField(tasks, "complexity_source")) {
    tasks.fields.add(new SelectField({
      name: "complexity_source",
      required: false,
      maxSelect: 1,
      values: [
        "auto",
        "executor_adjusted",
        "support_adjusted"
      ]
    }));
  }

  app.save(orders);
  app.save(applications);
  app.save(tasks);
});
