migrate((app) => {
  function replaceFieldWithFile(collectionName, fieldName, options) {
    const collection = app.findCollectionByNameOrId(collectionName)

    collection.fields.removeByName(fieldName)

    collection.fields.add(
      new FileField({
        name: fieldName,
        required: false,
        maxSelect: options.maxSelect,
        maxSize: options.maxSize,
        mimeTypes: options.mimeTypes,
        thumbs: options.thumbs || [],
        protected: false,
      })
    )

    app.save(collection)
  }

  replaceFieldWithFile("users", "photo", {
    maxSelect: 1,
    maxSize: 5242880,
    mimeTypes: ["image/jpeg", "image/png", "image/webp"],
    thumbs: ["100x100", "300x300"],
  })

  replaceFieldWithFile("order_attachments", "url", {
    maxSelect: 1,
    maxSize: 10485760,
    mimeTypes: [
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
      "text/plain",
      "application/zip",
    ],
    thumbs: ["300x300"],
  })

  replaceFieldWithFile("task_message_attachments", "photo", {
    maxSelect: 1,
    maxSize: 10485760,
    mimeTypes: [
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
      "text/plain",
      "application/zip",
    ],
    thumbs: ["300x300"],
  })

  replaceFieldWithFile("support_request_attachments", "photo", {
    maxSelect: 1,
    maxSize: 10485760,
    mimeTypes: [
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
      "text/plain",
      "application/zip",
    ],
    thumbs: ["300x300"],
  })
}, (app) => {
  function replaceFieldWithText(collectionName, fieldName) {
    const collection = app.findCollectionByNameOrId(collectionName)

    collection.fields.removeByName(fieldName)

    collection.fields.add(
      new TextField({
        name: fieldName,
        required: false,
        max: 0,
      })
    )

    app.save(collection)
  }

  replaceFieldWithText("users", "photo")
  replaceFieldWithText("order_attachments", "url")
  replaceFieldWithText("task_message_attachments", "photo")
  replaceFieldWithText("support_request_attachments", "photo")
})