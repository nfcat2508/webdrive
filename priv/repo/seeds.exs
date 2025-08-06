# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Webdrive.Repo.insert!(%Webdrive.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
{:ok, user} = Webdrive.Accounts.register_user(%{email: "user1@test.de", password: "password4242"})

Webdrive.Accounts.deliver_user_confirmation_instructions(user, fn token ->
  Webdrive.Accounts.confirm_user(token)
  "Ok"
end)
