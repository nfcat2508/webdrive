defmodule Webdrive.Files.UploadRequest do
  @moduledoc """
  The schema for requesting a specific upload
  """

  use Ecto.Schema
  import Ecto.Changeset
  import ChangesetUtils

  embedded_schema do
    # just use the default id :binary_id
  end

  @doc false
  def changeset(attrs) do
    %Webdrive.Files.UploadRequest{}
    |> cast(attrs, [:id])
    |> validate_required(:id)
    |> validate_uuid(:id)
  end
end
