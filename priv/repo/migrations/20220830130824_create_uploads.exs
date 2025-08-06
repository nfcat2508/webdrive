defmodule Owlstore.Repo.Migrations.CreateUploads do
  use Ecto.Migration

  def change do
    create table(:uploads, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :string, null: false
      add :owner, :string, null: false
      add :size, :integer, null: false
      add :content_type, :string, null: false
      add :hash, :string, size: 128, null: false
      add :encrypted, :boolean, null: false

      timestamps()
    end

    create index(:uploads, [:hash])
    create index(:uploads, [:owner])
  end
end
