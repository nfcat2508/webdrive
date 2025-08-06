defmodule Webdrive.Files.FileSharingRequest do
  @moduledoc """
  The schema for a file sharing request
  """

  use Ecto.Schema
  import Ecto.Changeset
  import ChangesetUtils

  @primary_key false
  embedded_schema do
    field :id, :string
    field :secret, :string, redact: true
  end

  @doc false
  def changeset(attrs) do
    %Webdrive.Files.FileSharingRequest{}
    |> cast(attrs, [:id, :secret])
    |> validate_required([:id, :secret])
    |> validate_length(:secret, min: 1, max: 72)
    |> validate_length(:id, max: 50)
    |> validate_chars(:id, ~r"[a-zA-Z0-9_=-]")
  end
end
