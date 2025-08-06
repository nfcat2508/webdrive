defmodule Webdrive.Repo.Migrations.MakeContentTypeOptional do
  use Ecto.Migration

  def change do
    alter table(:uploads) do
      modify :content_type, :string, null: true
    end
  end
end
