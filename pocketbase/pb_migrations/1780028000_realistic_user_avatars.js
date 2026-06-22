/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  const avatarsByEmail = {
    "customer@test.ru": "https://randomuser.me/api/portraits/men/32.jpg",
    "executor@test.ru": "https://randomuser.me/api/portraits/men/75.jpg",
    "support@test.ru": "https://randomuser.me/api/portraits/women/44.jpg",
    "anna.customer@test.ru": "https://randomuser.me/api/portraits/women/68.jpg",
    "max.executor@test.ru": "https://randomuser.me/api/portraits/men/52.jpg",
    "elena.executor@test.ru": "https://randomuser.me/api/portraits/women/26.jpg",
    "ivan.executor@test.ru": "https://randomuser.me/api/portraits/men/41.jpg",
  }

  function setPhoto(record, url) {
    try {
      record.set("photo", $filesystem.fileFromURL(url, 30))
      app.save(record)
    } catch (_) {}
  }

  for (const email in avatarsByEmail) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      setPhoto(record, avatarsByEmail[email])
    } catch (_) {}
  }

  const danUsers = app.findRecordsByFilter(
    "users",
    `name = "Даниил Кравцов" || email ~ "dan"`,
    "",
    10,
    0,
  )

  for (const record of danUsers) {
    setPhoto(record, "https://randomuser.me/api/portraits/men/22.jpg")
  }
}, (app) => {
  // Не откатываем загруженные фото.
})
