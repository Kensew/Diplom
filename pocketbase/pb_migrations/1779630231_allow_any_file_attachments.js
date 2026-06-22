migrate((app) => {
  function allowAnyFile(collectionName, fieldName, maxSize) {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = collection.fields.getByName(fieldName)

    field.maxSize = maxSize
    field.mimeTypes = []
    field.thumbs = ["300x300"]

    app.save(collection)
  }

  allowAnyFile("order_attachments", "url", 52428800)
  allowAnyFile("task_message_attachments", "photo", 52428800)
  allowAnyFile("support_request_attachments", "photo", 52428800)
}, (app) => {
  function restoreCommonFileTypes(collectionName, fieldName, maxSize) {
    const collection = app.findCollectionByNameOrId(collectionName)
    const field = collection.fields.getByName(fieldName)

    field.maxSize = maxSize
    field.mimeTypes = [
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
      "text/plain",
      "application/zip"
    ]
    field.thumbs = ["300x300"]

    app.save(collection)
  }

  restoreCommonFileTypes("order_attachments", "url", 10485760)
  restoreCommonFileTypes("task_message_attachments", "photo", 10485760)
  restoreCommonFileTypes("support_request_attachments", "photo", 10485760)
})