migrate((app) => {
  const feedbacks = app.findCollectionByNameOrId("feedbacks");
  const users = app.findCollectionByNameOrId("users");

  function hasField(collection, name) {
    try {
      collection.fields.getByName(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  if (!hasField(feedbacks, "reviewer_id")) {
    feedbacks.fields.add(new RelationField({
      name: "reviewer_id",
      required: false,
      maxSelect: 1,
      collectionId: users.id,
      cascadeDelete: false
    }));
  }

  if (!hasField(feedbacks, "reviewed_user_id")) {
    feedbacks.fields.add(new RelationField({
      name: "reviewed_user_id",
      required: false,
      maxSelect: 1,
      collectionId: users.id,
      cascadeDelete: false
    }));
  }

  if (!hasField(feedbacks, "type")) {
    feedbacks.fields.add(new SelectField({
      name: "type",
      required: false,
      maxSelect: 1,
      values: [
        "customer_to_executor",
        "executor_to_customer"
      ]
    }));
  }

  app.save(feedbacks);
});