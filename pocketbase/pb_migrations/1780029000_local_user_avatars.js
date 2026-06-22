/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const avatarDir = $filepath.join(
    $os.getwd(),
    "pb_migrations",
    "seed_assets",
    "avatars",
  )

  const avatarsByEmail = {
    "customer@test.ru": "pavel_sokolov.jpg",
    "executor@test.ru": "andrey_klimov.jpg",
    "support@test.ru": "olga_morozova.jpg",
    "anna.customer@test.ru": "anna_petrova.jpg",
    "max.executor@test.ru": "maxim_orlov.jpg",
    "elena.executor@test.ru": "elena_smirnova.jpg",
    "ivan.executor@test.ru": "ivan_temp.jpg",
  }

  function setPhoto(record, fileName) {
    const localPath = $filepath.join(avatarDir, fileName)
    const stat = $os.stat(localPath)
    if (!stat || stat.isDir()) {
      throw new Error("Avatar file not found: " + localPath)
    }

    record.set("photo", $filesystem.fileFromPath(localPath))
    app.save(record)
  }

  for (const email in avatarsByEmail) {
    const record = app.findAuthRecordByEmail("users", email)
    setPhoto(record, avatarsByEmail[email])
  }

  const danUsers = app.findRecordsByFilter(
    "users",
    `name = "Даниил Кравцов" || email ~ "dan"`,
    "",
    10,
    0,
  )

  for (const record of danUsers) {
    setPhoto(record, "daniil_kravtsov.jpg")
  }
}, (app) => {
  // Не откатываем загруженные фото.
})
