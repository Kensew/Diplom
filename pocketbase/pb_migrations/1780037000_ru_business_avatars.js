/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const avatarDir = $filepath.join(
    $os.getwd(),
    "pb_migrations",
    "seed_assets",
    "avatars",
  )

  const avatarsByEmail = {
    "customer@test.ru": "user_original_1.jpg",
    "executor@test.ru": "user_original_2.jpg",
    "support@test.ru": "olga_morozova.jpg",
    "anna.customer@test.ru": "anna_petrova.jpg",
    "max.executor@test.ru": "maxim_orlov.jpg",
    "elena.executor@test.ru": "elena_smirnova.jpg",
    "ivan.executor@test.ru": "ivan_kuznetsov.jpg",
  }

  const genderByEmail = {
    "customer@test.ru": "male",
    "executor@test.ru": "male",
    "support@test.ru": "female",
    "anna.customer@test.ru": "female",
    "max.executor@test.ru": "male",
    "elena.executor@test.ru": "female",
    "ivan.executor@test.ru": "male",
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
    if (genderByEmail[email]) {
      record.set("gender", genderByEmail[email])
      app.save(record)
    }
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
    record.set("gender", "male")
    app.save(record)
  }
}, (app) => {
  // Не откатываем загруженные фото.
})
