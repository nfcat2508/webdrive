defmodule Owlstore.Repo.Migrations.CreateFileSharings do
  use Ecto.Migration

  def change do
    create table(:file_sharings, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :identifier, :binary
      add :secret, :string
      add :upload_id, references(:uploads, on_delete: :delete_all, type: :binary_id)
      add :owner, :string, null: false

      timestamps()
    end

    create index(:file_sharings, [:upload_id])
    create unique_index(:file_sharings, [:identifier])
  end
end
