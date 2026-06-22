/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_")

  const supportRule =
    '@request.auth.id != "" && (@request.auth.role = "support" || @request.auth.email = "support@test.ru")'

  let userBans
  try {
    userBans = app.findCollectionByNameOrId("user_bans")
  } catch (_) {
    userBans = new Collection({
      type: "base",
      name: "user_bans",
      listRule: '@request.auth.id != ""',
      viewRule: '@request.auth.id != ""',
      createRule: supportRule,
      updateRule: supportRule,
      deleteRule: supportRule,
      fields: [
        {
          type: "relation",
          name: "user_id",
          required: true,
          collectionId: users.id,
          maxSelect: 1,
        },
        {
          type: "text",
          name: "reason",
          required: true,
        },
        {
          type: "date",
          name: "banned_at",
          required: false,
        },
        {
          type: "relation",
          name: "banned_by",
          required: false,
          collectionId: users.id,
          maxSelect: 1,
        },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_user_bans_user_id ON user_bans (user_id)",
      ],
    })
    app.save(userBans)
  }

  userBans.listRule = '@request.auth.id != ""'
  userBans.viewRule = '@request.auth.id != ""'
  userBans.createRule = supportRule
  userBans.updateRule = supportRule
  userBans.deleteRule = supportRule
  app.save(userBans)

  try {
    const support = app.findAuthRecordByEmail("users", "support@test.ru")
    support.set("role", "support")
    app.save(support)
  } catch (_) {}
}, (app) => {
  try {
    const userBans = app.findCollectionByNameOrId("user_bans")
    app.delete(userBans)
  } catch (_) {}
})
