defmodule Webdrive.Files.Upload do
  @moduledoc """
  The schema for a file upload. Contains all meta data for an uploaded file
  """

  use Ecto.Schema
  import Ecto.Changeset
  import ChangesetUtils

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "uploads" do
    field :content_type, :string
    field :hash, :string
    field :name, :string
    field :owner, :string
    field :size, :integer
    field :encrypted, :boolean

    has_one :sharing, Webdrive.Files.FileSharing

    timestamps()
  end

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:name, :owner, :size, :content_type, :hash, :encrypted])
    |> validate_required([:name, :owner, :size, :hash, :encrypted])
    |> validate_length(:name, max: 100)
    |> validate_length(:content_type, max: 100)
    |> replace_sanitized(:content_type, ~r"[[:alnum:]+-/.]")
    |> replace_sanitized(:name, ~r"[[:alnum:]-_#.]")
  end

  @doc false
  def sha512(chunks_enum) do
    chunks_enum
    |> Enum.reduce(
      :crypto.hash_init(:sha512),
      &:crypto.hash_update(&2, &1)
    )
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  @doc false
  def local_path(id, filename) do
    [upload_directory(), "#{id}-#{filename}"]
    |> Path.join()
  end

  @doc false
  def upload_directory do
    Application.fetch_env!(:webdrive, :uploads_directory)
  end

  @doc false
  def find_local_file(id) do
    with filename when is_binary(filename) <- find_filename_starting_with(id) do
      Path.join([upload_directory(), filename])
    end
  end

  defp find_filename_starting_with(id) do
    upload_directory()
    |> File.ls!()
    |> Enum.find(&String.starts_with?(&1, "#{id}-"))
  end
end
