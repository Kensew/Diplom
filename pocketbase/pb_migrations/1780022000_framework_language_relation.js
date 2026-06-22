/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const frameworks = app.findCollectionByNameOrId("frameworks")
  const languages = app.findCollectionByNameOrId("languages")

  const hasField = (collection, name) => {
    const field = collection.fields.getByName(name)
    return field !== null && field !== undefined
  }

  if (!hasField(frameworks, "language_id")) {
    frameworks.fields.add(new Field({
      id: "relfwlang001",
      name: "language_id",
      type: "relation",
      system: false,
      required: false,
      hidden: false,
      presentable: false,
      collectionId: languages.id,
      cascadeDelete: false,
      minSelect: 0,
      maxSelect: 1,
    }))
  }

  app.save(frameworks)

  function findLanguage(name) {
    return app.findFirstRecordByData("languages", "name", name)
  }

  function linkFramework(frameworkName, languageName) {
    try {
      const framework = app.findFirstRecordByData("frameworks", "name", frameworkName)
      const language = findLanguage(languageName)
      framework.set("language_id", language.id)
      app.save(framework)
    } catch (_) {}
  }

  linkFramework("Flutter", "Dart")
  linkFramework("React", "JavaScript")
  linkFramework("Django", "Python")
}, (app) => {
  const frameworks = app.findCollectionByNameOrId("frameworks")

  const field = frameworks.fields.getByName("language_id")
  if (field !== null && field !== undefined) {
    frameworks.fields.removeById(field.id)
  }

  app.save(frameworks)
})
