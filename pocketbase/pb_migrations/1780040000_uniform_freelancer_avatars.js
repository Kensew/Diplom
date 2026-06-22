/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const avatarDir = $filepath.join(
    $os.getwd(),
    "pb_migrations",
    "seed_assets",
    "avatars",
  )

  const avatarsByEmail = {
    "customer@test.ru": "freelancer_male_1.jpg",
    "executor@test.ru": "freelancer_male_2.jpg",
    "support@test.ru": "freelancer_female_1.jpg",
    "anna.customer@test.ru": "freelancer_female_2.jpg",
    "max.executor@test.ru": "freelancer_male_3.jpg",
    "elena.executor@test.ru": "freelancer_female_3.jpg",
    "ivan.executor@test.ru": "freelancer_male_4.jpg",
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
    record.set("gender", genderByEmail[email])
    app.save(record)
  }

  const danUsers = app.findRecordsByFilter(
    "users",
    `name = "Даниил Кравцов" || email ~ "dan"`,
    "",
    10,
    0,
  )

  for (const record of danUsers) {
    setPhoto(record, "freelancer_male_5.jpg")
    record.set("gender", "male")
    app.save(record)
  }
}, (app) => {
  // Не откатываем загруженные фото.
})
