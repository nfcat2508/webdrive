defmodule Webdrive.Files.FileSharing do
  @moduledoc """
  The schema for a file sharing identified by a unique String and secured with a password
  """

  use Ecto.Schema
  import Ecto.Changeset
  import ChangesetUtils

  @rand_size 32

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "file_sharings" do
    field :identifier, :string
    field :identifier_user_param, :string, virtual: true
    field :secret, :string, redact: true
    field :owner, :string

    belongs_to :upload, Webdrive.Files.Upload

    timestamps()
  end

  @doc false
  def changeset(file_sharing, attrs) do
    file_sharing
    |> cast(attrs, [:secret, :upload_id])
    |> validate_secret()
    |> validate_upload_id()
    |> validate_not_blank(:owner)
    |> hash_secret()
    |> add_identifier()
  end

  defp validate_not_blank(changeset, field) do
    if missing?(changeset, field) do
      add_error(changeset, field, "can't be blank")
    else
      changeset
    end
  end

  defp missing?(changeset, field) do
    case get_field(changeset, field) do
      value when is_binary(value) -> String.trim(value) == ""
      nil -> true
      _ -> false
    end
  end

  defp validate_secret(changeset) do
    changeset
    |> validate_required([:secret])
    |> validate_length(:secret, min: 12, max: 72)
    |> validate_format(:secret, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:secret, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:secret, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
  end

  defp hash_secret(changeset) do
    secret = get_change(changeset, :secret)

    if secret && changeset.valid? do
      changeset
      |> validate_length(:secret, max: 72, count: :bytes)
      |> update_change(:secret, &Argon2.hash_pwd_salt/1)
    else
      changeset
    end
  end

  defp validate_upload_id(changeset) do
    changeset
    |> validate_required([:upload_id])
    |> validate_uuid(:upload_id)
    |> foreign_key_constraint(:upload_id)
  end

  @doc false
  def valid_secret?(%Webdrive.Files.FileSharing{secret: hashed_secret}, secret)
      when byte_size(secret) > 0 do
    Argon2.verify_pass(secret, hashed_secret)
  end

  def valid_secret?(_, _) do
    Argon2.no_user_verify()
  end

  defp add_identifier(changeset) do
    if changeset.valid? do
      identifier = :crypto.strong_rand_bytes(@rand_size)

      changeset
      |> put_change(:identifier, identifier)
      |> put_change(:identifier_user_param, Base.url_encode64(identifier, padding: false))
    else
      changeset
    end
  end

  @doc false
  def decode_identifier(identifier_user_param) when is_binary(identifier_user_param) do
    case Base.url_decode64(identifier_user_param, padding: false) do
      {:ok, decoded_identifier} -> decoded_identifier
      :error -> :error
    end
  end

  def decode_identifier(_), do: :error
end
